# ReflectView Customer Provisioning UI

A web-based interface for provisioning new ReflectView customers using Terraform.

## Features

- **Step-by-step wizard** for customer provisioning
- **Automatic configuration generation** for EC2, ALB, and RDS
- **Preview configurations** before applying
- **Copy to clipboard** for manual application
- **Automated Terraform execution** (optional)
- **Input validation** and sanitization
- **Responsive design** for desktop and mobile

## Prerequisites

- Node.js 16+ installed
- Access to the Reflect-View-Infrastructure repository
- AWS CLI configured with appropriate credentials
- Terraform installed

## Installation

1. Navigate to the provisioning-ui directory:
```bash
cd Reflect-View-Infrastructure/provisioning-ui
```

2. Install dependencies:
```bash
npm install
```

## Usage

### Start the Server

```bash
npm start
```

The UI will be available at: http://localhost:3000

For development with auto-reload:
```bash
npm run dev
```

### Provisioning a New Customer

1. **Open the UI** in your browser: http://localhost:3000

2. **Step 1: Customer Information**
   - Enter customer name (will be sanitized automatically)
   - Select target environment (prod1, prod2, prod3, dev, staging)

3. **Step 2: EC2 Configuration**
   - Choose instance type (t3.medium, t3.large, etc.)
   - Set root EBS size (default: 80 GB)
   - Select subnet ID (use RapidScale-approved subnets)
   - Specify AMI ID (default: Windows Server 2022)

4. **Step 3: ALB Configuration**
   - Set host header (auto-generated from customer name)
   - Configure backend port (default: 443)
   - Set ALB rule priority (must be unique, 100 is reserved)

5. **Step 4: RDS Configuration (Optional)**
   - Check "Provision dedicated RDS instance" if needed
   - Select RDS instance class
   - Set allocated storage

6. **Step 5: Review & Apply**
   - Review generated configurations
   - Copy to clipboard for manual application, OR
   - Click "Apply to Terraform" to write configurations automatically

### Manual Application

If you prefer to apply configurations manually:

1. Copy the generated configurations
2. Navigate to the appropriate stack directory:
   ```bash
   cd Reflect-View-Infrastructure/live/<environment>/compute
   ```
3. Edit `terraform.auto.tfvars` and add the EC2 configuration
4. Run Terraform:
   ```bash
   terraform plan
   terraform apply
   ```
5. Repeat for ALB and RDS stacks

### Automated Application

The UI can write configurations directly to Terraform files:

1. Click "Apply to Terraform" in Step 5
2. Configurations will be appended to the appropriate `terraform.auto.tfvars` files
3. Navigate to each stack directory and run:
   ```bash
   terraform plan   # Review changes
   terraform apply  # Apply changes
   ```

## API Endpoints

### GET /api/environments
Returns list of available environments.

### GET /api/config/:environment/:stack
Returns current Terraform configuration for a stack.

### POST /api/generate-config
Generates Terraform configuration for a new customer.

**Request Body:**
```json
{
  "customerName": "Acme Corporation",
  "environment": "cri-ct-rv-prod1",
  "instanceType": "t3.medium",
  "rootEbsSize": 80,
  "subnetId": "subnet-xxx",
  "amiId": "ami-xxx",
  "hostHeader": "acme.hosted.reflectsystems.com",
  "backendPort": 443,
  "priority": 200,
  "rdsInstanceClass": "db.t3.medium",
  "rdsStorage": 100
}
```

### POST /api/apply-config
Writes configuration to Terraform files.

**Request Body:**
```json
{
  "environment": "cri-ct-rv-prod1",
  "stack": "compute",
  "config": "...",
  "autoApply": false
}
```

### POST /api/terraform/:command
Executes Terraform commands (plan, apply, destroy).

**Request Body:**
```json
{
  "environment": "cri-ct-rv-prod1",
  "stack": "compute"
}
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Authentication**: This UI does not include authentication. Deploy behind a VPN or add authentication before production use.

2. **Authorization**: Ensure only authorized personnel can access the UI.

3. **Terraform State**: The UI requires access to Terraform state files in S3. Ensure proper IAM permissions.

4. **Auto-Apply**: The automated Terraform execution feature should be used with caution. Consider requiring manual approval for production environments.

5. **Input Validation**: While the UI validates inputs, always review generated configurations before applying.

## Configuration

### Environment Variables

Create a `.env` file in the provisioning-ui directory:

```env
PORT=3000
TERRAFORM_BASE_PATH=../live
AWS_PROFILE=your-aws-profile
```

### Customization

- **Port**: Change `PORT` in `server.js` or use environment variable
- **Terraform Path**: Modify `TERRAFORM_BASE_PATH` to point to your Terraform directory
- **Environments**: Update `ENVIRONMENTS` array in `server.js` to add/remove environments

## Troubleshooting

### Server won't start
- Check that port 3000 is not in use
- Verify Node.js is installed: `node --version`
- Check dependencies are installed: `npm install`

### Can't load environments
- Ensure the server is running
- Check browser console for errors
- Verify API_BASE URL in `app.js` matches your server

### Terraform commands fail
- Verify AWS CLI is configured: `aws sts get-caller-identity`
- Check Terraform is installed: `terraform version`
- Ensure you have access to the Terraform state bucket

### Configuration not applied
- Check file permissions on `terraform.auto.tfvars` files
- Verify the Terraform directory path is correct
- Review server logs for errors

## Future Enhancements

- [ ] Add authentication (OAuth, SAML, etc.)
- [ ] Implement approval workflow for production changes
- [ ] Add Terraform plan preview in UI
- [ ] Support for bulk customer provisioning
- [ ] Integration with ticketing systems (Jira, ServiceNow)
- [ ] Audit logging for all provisioning actions
- [ ] Email notifications on completion
- [ ] Rollback functionality
- [ ] Cost estimation before provisioning
- [ ] Resource tagging management

## Support

For issues or questions, contact the CRI Infrastructure team.

## License

Internal use only - Creative Realities, Inc.
