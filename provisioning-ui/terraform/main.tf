terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Using local backend for now since rv-shared profile doesn't have access to Shared Services S3
  # TODO: Create S3 bucket in rv-shared account for state storage
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  
  # Using direct credentials from rv-shared SSO profile
  # No role assumption needed since we have AdministratorAccess
}

# Data sources for VPC and subnets
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnet" "private" {
  id = data.aws_subnets.private.ids[0]
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Provisioning UI
resource "aws_security_group" "provisioning_ui" {
  name_prefix = "provisioning-ui-"
  description = "Security group for ReflectView Provisioning UI"
  vpc_id      = data.aws_vpc.main.id
  
  # Allow HTTPS from VPC (for internal access)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }
  
  # Allow HTTP from VPC (will redirect to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "HTTP from VPC"
  }
  
  # Allow Node.js app port from VPC
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Node.js app from VPC"
  }
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
  
  tags = {
    Name        = "provisioning-ui-sg"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "provisioning_ui" {
  name_prefix = "provisioning-ui-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "provisioning-ui-role"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for Terraform execution
resource "aws_iam_role_policy" "terraform_execution" {
  name_prefix = "terraform-execution-"
  role        = aws_iam_role.provisioning_ui.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::530258393729:role/terraform-execute-cri",
          "arn:aws:iam::164804042272:role/terraform-execute",
          "arn:aws:iam::109743757398:role/terraform-execute"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::cri-terraform-state-backend",
          "arn:aws:s3:::cri-terraform-state-backend/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:530258393729:table/cri-terraform-locks"
      }
    ]
  })
}

# Attach SSM managed policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.provisioning_ui.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch agent policy
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.provisioning_ui.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "provisioning_ui" {
  name_prefix = "provisioning-ui-"
  role        = aws_iam_role.provisioning_ui.name
  
  tags = {
    Name        = "provisioning-ui-profile"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# Secrets Manager secret for GitHub token
resource "aws_secretsmanager_secret" "github_token" {
  name_prefix             = "provisioning-ui-github-token-"
  description             = "GitHub Personal Access Token for Provisioning UI"
  recovery_window_in_days = 7
  
  tags = {
    Name        = "provisioning-ui-github-token"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# User data script to set up the instance
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install Node.js 18
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs
    
    # Install Git
    yum install -y git
    
    # Install Terraform
    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum install -y terraform
    
    # Install AWS CLI v2 (already included in AL2023)
    
    # Create app directory
    mkdir -p /opt/provisioning-ui
    cd /opt/provisioning-ui
    
    # Clone repository (will be done manually or via CodeDeploy)
    # For now, create placeholder
    
    # Create systemd service
    cat > /etc/systemd/system/provisioning-ui.service <<'SERVICE'
    [Unit]
    Description=ReflectView Provisioning UI
    After=network.target
    
    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/provisioning-ui
    ExecStart=/usr/bin/node server.js
    Restart=always
    RestartSec=10
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=provisioning-ui
    
    Environment=NODE_ENV=production
    Environment=PORT=3000
    
    [Install]
    WantedBy=multi-user.target
    SERVICE
    
    # Set permissions
    chown -R ec2-user:ec2-user /opt/provisioning-ui
    
    # Enable service (will start after code is deployed)
    systemctl daemon-reload
    systemctl enable provisioning-ui
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    
    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CWCONFIG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/aws/ec2/provisioning-ui",
                "log_stream_name": "{instance_id}/system"
              },
              {
                "file_path": "/var/log/cloud-init-output.log",
                "log_group_name": "/aws/ec2/provisioning-ui",
                "log_stream_name": "{instance_id}/cloud-init"
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "ProvisioningUI",
        "metrics_collected": {
          "mem": {
            "measurement": [
              {
                "name": "mem_used_percent",
                "rename": "MemoryUtilization",
                "unit": "Percent"
              }
            ],
            "metrics_collection_interval": 60
          },
          "disk": {
            "measurement": [
              {
                "name": "used_percent",
                "rename": "DiskUtilization",
                "unit": "Percent"
              }
            ],
            "metrics_collection_interval": 60,
            "resources": [
              "/"
            ]
          }
        }
      }
    }
    CWCONFIG
    
    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
    
    echo "Instance setup complete!"
  EOF
}

# EC2 Instance
resource "aws_instance" "provisioning_ui" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.provisioning_ui.id]
  iam_instance_profile   = aws_iam_instance_profile.provisioning_ui.name
  
  user_data = local.user_data
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  tags = {
    Name        = "provisioning-ui"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Application = "ReflectView Provisioning UI"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "provisioning_ui" {
  name              = "/aws/ec2/provisioning-ui"
  retention_in_days = 30
  
  tags = {
    Name        = "provisioning-ui-logs"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.provisioning_ui.id
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.provisioning_ui.private_ip
}

output "ssm_connect_command" {
  description = "Command to connect via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.provisioning_ui.id} --region ${var.aws_region}"
}

output "github_secret_arn" {
  description = "ARN of the GitHub token secret in Secrets Manager"
  value       = aws_secretsmanager_secret.github_token.arn
}

output "setup_instructions" {
  description = "Next steps to complete setup"
  value       = <<-EOT
    1. Store GitHub token in Secrets Manager:
       aws secretsmanager put-secret-value --secret-id ${aws_secretsmanager_secret.github_token.id} --secret-string "ghp_your_token_here"
    
    2. Connect to instance via SSM:
       aws ssm start-session --target ${aws_instance.provisioning_ui.id}
    
    3. Deploy application code:
       cd /opt/provisioning-ui
       git clone https://github.com/YOUR_ORG/Reflect-View-Infrastructure.git .
       cd provisioning-ui
       npm install
    
    4. Configure environment:
       Create /opt/provisioning-ui/provisioning-ui/.env with required values
    
    5. Start the service:
       sudo systemctl start provisioning-ui
       sudo systemctl status provisioning-ui
  EOT
}
