# Accessing the Provisioning UI

The Provisioning UI is deployed on a private EC2 instance (no public IP) for security. Here are the ways to access it:

## Option 1: SSM Port Forwarding (Recommended)

Use AWS Systems Manager Session Manager to forward port 3000 from the EC2 instance to your local machine.

### Prerequisites
- AWS CLI installed and configured
- Session Manager plugin installed: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- AWS SSO profile configured (`rv-shared`)

### Steps

1. **Login to AWS SSO**:
   ```bash
   aws sso login --profile rv-shared
   ```

2. **Start port forwarding**:
   ```bash
   aws ssm start-session \
     --target i-040c9ba3f55a32497 \
     --document-name AWS-StartPortForwardingSession \
     --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}' \
     --profile rv-shared \
     --region us-east-1
   ```

3. **Access the UI**:
   Open your browser to: http://localhost:3000

4. **Stop port forwarding**:
   Press `Ctrl+C` in the terminal where port forwarding is running

## Option 2: SSM Session Manager (Terminal Access)

Connect directly to the instance terminal:

```bash
aws ssm start-session \
  --target i-040c9ba3f55a32497 \
  --profile rv-shared \
  --region us-east-1
```

Once connected, you can:
- Check service status: `sudo systemctl status provisioning-ui`
- View logs: `sudo journalctl -u provisioning-ui -f`
- Test locally: `curl http://localhost:3000`

## Option 3: Add Application Load Balancer (Future Enhancement)

If you need external access without port forwarding, you can add an ALB:

1. Create ALB in public subnets
2. Create target group pointing to EC2 instance on port 3000
3. Configure SSL certificate
4. Add DNS record

This would require Terraform changes to add ALB resources.

## Current Deployment Status

- **Instance ID**: i-040c9ba3f55a32497
- **Private IP**: 10.11.2.118
- **Service Status**: Running ✅
- **Port**: 3000
- **Region**: us-east-1
- **Account**: rv-shared (786284303891)

## Troubleshooting

### Port forwarding fails
- Ensure Session Manager plugin is installed
- Check AWS SSO session is active: `aws sso login --profile rv-shared`
- Verify instance is running: `aws ec2 describe-instances --instance-ids i-040c9ba3f55a32497 --profile rv-shared --region us-east-1`

### Service not responding
- Check service status via SSM session
- View logs: `sudo journalctl -u provisioning-ui -f`
- Restart service: `sudo systemctl restart provisioning-ui`

### Cannot connect via SSM
- Verify IAM role has `AmazonSSMManagedInstanceCore` policy
- Check instance has internet access (via NAT Gateway)
- Ensure SSM agent is running on the instance
