#!/bin/bash
set -e

echo "Starting deployment..."

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
fi

# Create app directory
sudo mkdir -p /opt/provisioning-ui
cd /opt/provisioning-ui

# Download application from S3
echo "Downloading application..."
aws s3 cp s3://rv-shared-temp-1773421683/provisioning-ui.tar.gz /tmp/provisioning-ui.tar.gz

# Extract application
echo "Extracting application..."
sudo tar -xzf /tmp/provisioning-ui.tar.gz -C /opt/provisioning-ui --strip-components=1

# Install dependencies
echo "Installing dependencies..."
sudo npm install --production

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/provisioning-ui.service > /dev/null <<'EOF'
[Unit]
Description=ReflectView Provisioning UI
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/provisioning-ui
Environment="NODE_ENV=production"
Environment="PORT=3000"
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable provisioning-ui
sudo systemctl restart provisioning-ui

# Wait a moment and check status
sleep 3
sudo systemctl status provisioning-ui --no-pager

echo "Deployment complete!"
echo "Application should be running on port 3000"
