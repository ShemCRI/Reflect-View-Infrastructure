# Setup Guide: ReflectView Provisioning UI with GitHub Integration

## Prerequisites

1. **Node.js 16+** installed
2. **GitHub Personal Access Token** with repo permissions
3. **AWS CLI** configured with SSO access
4. **Terraform** installed
5. Access to the **Reflect-View-Infrastructure** repository

## Step 1: Install Dependencies

```bash
cd Reflect-View-Infrastructure/provisioning-ui
npm install
```

## Step 2: Configure GitHub Access

### Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "ReflectView Provisioning UI"
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
5. Click "Generate token"
6. **Copy the token** (you won't see it again!)

### Configure Environment Variables

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` and add your values:
```env
# Server Configuration
PORT=3000
NODE_ENV=development

# GitHub Configuration
GITHUB_TOKEN=ghp_your_actual_token_here
GITHUB_OWNER=your-github-org-or-username
GITHUB_REPO=Reflect-View-Infrastructure
GITHUB_BASE_BRANCH=main

# Terraform Configuration
TERRAFORM_BASE_PATH=../live

# AWS Configuration
AWS_REGION=us-east-1
AWS_SHARED_SERVICES_ACCOUNT=530258393729
```

## Step 3: Update Account Configuration

Edit `config.js` to add your actual AWS account IDs and KMS keys:

```javascript
environments: {
  'cri-ct-rv-dev': {
    name: 'Development',
    accountId: '164804042272',  // ✅ Already configured
    // ...
  },
  'cri-ct-rv-staging': {
    name: 'Staging',
    accountId: 'YOUR_STAGING_ACCOUNT_ID',  // ⚠️ Update this
    // ...
  },
  // ... update other accounts
},

kmsKeys: {
  '164804042272': 'arn:aws:kms:us-east-1:164804042272:key/YOUR_DEV_KMS_KEY',  // ⚠️ Update this
  '109743757398': 'arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89',  // ✅ Already configured
  // ... add other account KMS keys
},

subnets: {
  'cri-ct-rv-dev': [
    'subnet-REPLACE-WITH-ACTUAL-DEV-SUBNET-1',  // ⚠️ Update these
    'subnet-REPLACE-WITH-ACTUAL-DEV-SUBNET-2',
    'subnet-REPLACE-WITH-ACTUAL-DEV-SUBNET-3'
  ],
  // ... add other environment subnets
}
```

## Step 4: Test the Setup

### Start the Server

```bash
npm start
```

You should see:
```
ReflectView Provisioning UI running on http://localhost:3000
```

### Open in Browser

Navigate to: http://localhost:3000

### Test Environment Loading

1. The environment dropdown should show all configured environments
2. Select "Development (164804042272)"
3. You should see:
   - AWS Account: 164804042272
   - Region: us-east-1
   - Description: Development environment for testing
   - Badge: ✅ Auto-Apply Enabled (or ⚠️ Requires Approval)

## Step 5: Test Provisioning Flow

### Create a Test Customer

1. **Step 1**: Enter customer name "Test Customer"
2. **Step 2**: Select environment "cri-ct-rv-dev"
3. **Step 3**: Configure EC2 (use defaults)
4. **Step 4**: Configure ALB (use defaults)
5. **Step 5**: Skip RDS
6. **Step 6**: Click "Generate Configuration"
7. **Step 7**: Review the generated Terraform code

### Create Pull Request

1. Click "🔀 Create Pull Request"
2. Wait for confirmation
3. Click the PR link to view on GitHub
4. You should see:
   - New branch created: `provision-test-customer-<timestamp>`
   - Pull request with all configuration details
   - Terraform code in expandable sections

### Verify on GitHub

1. Go to your GitHub repository
2. Check "Pull requests" tab
3. You should see the new PR
4. Review the changes in the "Files changed" tab
5. You should see updates to:
   - `live/cri-ct-rv-dev/compute/terraform.auto.tfvars`
   - `live/cri-ct-rv-dev/alb/terraform.auto.tfvars`

## Step 6: Set Up GitHub Actions (Optional)

Create `.github/workflows/terraform-pr.yml` to automatically run `terraform plan` on PRs:

```yaml
name: Terraform PR Validation

on:
  pull_request:
    paths:
      - 'live/**/terraform.auto.tfvars'

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::530258393729:role/terraform-execute-cri
          aws-region: us-east-1
          
      - name: Terraform Init & Plan
        run: |
          for dir in live/*/compute live/*/alb live/*/rds; do
            if [ -d "$dir" ]; then
              echo "Planning $dir..."
              cd $dir
              terraform init
              terraform plan -no-color
              cd -
            fi
          done
```

## Troubleshooting

### Error: "Failed to load environments"

**Cause**: Server not running or wrong API URL

**Solution**:
1. Check server is running: `npm start`
2. Verify API_BASE in `public/app.js` matches your server URL

### Error: "Failed to create pull request"

**Cause**: GitHub token invalid or insufficient permissions

**Solution**:
1. Verify GITHUB_TOKEN in `.env` is correct
2. Check token has `repo` scope
3. Verify GITHUB_OWNER and GITHUB_REPO are correct
4. Check server logs for detailed error

### Error: "Invalid environment"

**Cause**: Environment not configured in `config.js`

**Solution**:
1. Check `config.js` has the environment defined
2. Verify accountId is set
3. Restart server after config changes

### Error: "KMS key not found"

**Cause**: KMS key not configured for the account

**Solution**:
1. Add KMS key ARN to `config.kmsKeys` in `config.js`
2. Get KMS key from AWS Console or ask infrastructure team

## Security Best Practices

1. **Never commit `.env` file** - it's in `.gitignore`
2. **Rotate GitHub tokens** regularly (every 90 days)
3. **Use least-privilege** GitHub token scopes
4. **Enable 2FA** on GitHub account
5. **Review PRs** before merging, even in dev
6. **Audit logs** - GitHub tracks all API usage

## Production Deployment

For production use, consider:

1. **Deploy behind VPN** or add authentication
2. **Use AWS Secrets Manager** for GitHub token
3. **Enable audit logging** to CloudWatch
4. **Set up monitoring** and alerting
5. **Require PR approvals** for production environments
6. **Use dedicated service account** for GitHub API

## Support

For issues or questions:
- Check server logs: `npm start` output
- Review GitHub API rate limits: https://api.github.com/rate_limit
- Contact CRI Infrastructure team

## Next Steps

1. ✅ Test provisioning in dev environment
2. ✅ Set up GitHub Actions for terraform plan
3. ✅ Configure Slack/Teams notifications (optional)
4. ✅ Add authentication for production use
5. ✅ Deploy to EC2 or ECS for team access


## AWS SSO Configuration (Optional)

### 1. Create SAML Application in AWS SSO

1. Go to AWS SSO Console → Applications
2. Click "Add a new application"
3. Choose "Add a custom SAML 2.0 application"
4. Configure:
   - **Application name**: ReflectView Provisioning UI
   - **Application start URL**: `https://provisioning-ui.your-domain.com`
   - **Application ACS URL**: `https://provisioning-ui.your-domain.com/auth/callback`
   - **Application SAML audience**: `provisioning-ui`

### 2. Download Certificate

1. In the application configuration, download the "AWS SSO SAML metadata"
2. Extract the X.509 certificate
3. Add to `.env` file as `AWS_SSO_CERT`

### 3. Assign Users

1. In AWS SSO, go to the application
2. Click "Assign users"
3. Add CRI engineers who should have access

### 4. Enable SSO in Application

Add these to your `.env` file:

```bash
AWS_SSO_ENABLED=true
AWS_SSO_ENTRY_POINT=https://portal.sso.us-east-1.amazonaws.com/saml/assertion/YOUR_APP_ID
AWS_SSO_ISSUER=provisioning-ui
AWS_SSO_CALLBACK_URL=https://provisioning-ui.your-domain.com/auth/callback
AWS_SSO_CERT="-----BEGIN CERTIFICATE-----
YOUR_X509_CERTIFICATE_HERE
-----END CERTIFICATE-----"
SESSION_SECRET=$(openssl rand -base64 32)
```

Restart the service: `sudo systemctl restart provisioning-ui`

## Slack Notifications

The application sends Slack notifications for:
- ✅ New provisioning requests (with PR link)
- ❌ Provisioning errors
- ✅ Terraform plan success (via GitHub Actions)
- ❌ Terraform plan failures (via GitHub Actions)

### Configure Slack Webhook

1. Go to your Slack workspace
2. Create an Incoming Webhook for the `#cloud-ops-internal` channel (or your preferred channel)
3. Copy the webhook URL
4. Add to `.env` as `SLACK_WEBHOOK_URL`
5. Add to GitHub Secrets as `SLACK_WEBHOOK_URL` (for GitHub Actions notifications)

Example `.env` entry:
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## GitHub Actions Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/terraform-pr-validation.yml`) that:

1. Detects changed environments in PRs
2. Runs `terraform plan` for each changed stack (compute, alb, rds)
3. Comments the plan output on the PR
4. Sends Slack notifications on success/failure

### Setup GitHub Secrets

Add this secret to your GitHub repository (Settings → Secrets and variables → Actions):

- `SLACK_WEBHOOK_URL`: Your Slack webhook URL for notifications

The workflow runs automatically when PRs are created by the Provisioning UI.

## Additional Troubleshooting

### AWS SSO Login Fails

1. Verify `AWS_SSO_ENABLED=true` in `.env`
2. Check certificate is correctly formatted (no extra spaces/newlines)
3. Verify callback URL matches AWS SSO configuration
4. Check application logs for SAML errors:
   ```bash
   sudo journalctl -u provisioning-ui -f | grep -i saml
   ```

### Slack Notifications Not Working

```bash
# Test webhook manually
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  YOUR_SLACK_WEBHOOK_URL

# Check webhook URL in .env
grep SLACK_WEBHOOK_URL /opt/provisioning-ui/provisioning-ui/.env

# Check application logs
sudo journalctl -u provisioning-ui -f | grep -i slack
```

### GitHub Actions Not Running

1. Verify `SLACK_WEBHOOK_URL` is set in GitHub Secrets
2. Check workflow file exists: `.github/workflows/terraform-pr-validation.yml`
3. Verify workflow has correct permissions in repository settings
4. Check Actions tab in GitHub for workflow runs and errors

## Security Best Practices

1. **Enable AWS SSO**: Always enable AWS SSO for production deployments
2. **Use HTTPS**: Set up ALB with HTTPS and ACM certificate
3. **Rotate Secrets**: Regularly rotate GitHub tokens and session secrets
4. **Limit Access**: Use AWS SSO to control who can access the UI
5. **Monitor Logs**: Regularly review CloudWatch logs for suspicious activity
6. **Update Dependencies**: Keep Node.js packages up to date

## Feature Summary

✅ **Completed Features:**
- 5-step wizard for customer provisioning
- Multi-account support (Dev, Staging, Prod1, Prod2, Prod3)
- GitHub PR workflow with branch creation
- Terraform configuration generation (EC2, ALB, RDS)
- AWS SSO authentication (optional)
- Slack notifications for provisioning events
- GitHub Actions workflow for automatic terraform plan
- CloudWatch logging and metrics
- IAM roles for Terraform execution

🚀 **Ready for Production Use!**
