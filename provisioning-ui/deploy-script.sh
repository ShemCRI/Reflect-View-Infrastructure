#!/bin/bash
set -e

echo "=== Starting Provisioning UI Deployment ==="

# Navigate to app directory
cd /opt/provisioning-ui

# Clone repository if not already cloned
if [ ! -d ".git" ]; then
    echo "Cloning repository..."
    git clone https://github.com/CRI-iAtlas/Reflect-View-Infrastructure.git .
else
    echo "Repository already cloned, pulling latest..."
    git pull
fi

# Navigate to provisioning-ui folder
cd provisioning-ui

# Install dependencies
echo "Installing Node.js dependencies..."
npm install

# Create .env file
echo "Creating .env file..."
cat > .env << 'EOF'
# Server Configuration
PORT=3000
NODE_ENV=production

# GitHub Configuration
GITHUB_TOKEN=REPLACE_WITH_YOUR_TOKEN
GITHUB_OWNER=CRI-iAtlas
GITHUB_REPO=Reflect-View-Infrastructure
GITHUB_BASE_BRANCH=main

# AWS SSO Authentication (disabled for now)
AWS_SSO_ENABLED=false

# Session Secret
SESSION_SECRET=REPLACE_WITH_RANDOM_SECRET

# Slack Notifications (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T068L772TV0/B08JMFV7ZQE/YOUR_WEBHOOK_HERE
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/provisioning-ui

echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit /opt/provisioning-ui/provisioning-ui/.env and add your GitHub token"
echo "2. Start the service: sudo systemctl start provisioning-ui"
echo "3. Check status: sudo systemctl status provisioning-ui"
echo "4. View logs: sudo journalctl -u provisioning-ui -f"
echo ""
echo "Access the UI at: http://10.11.2.118:3000"
