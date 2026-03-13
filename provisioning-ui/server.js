require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const { Octokit } = require('@octokit/rest');
const simpleGit = require('simple-git');
const session = require('express-session');
const passport = require('passport');
const { Strategy: SamlStrategy } = require('passport-saml');
const axios = require('axios');
const config = require('./config');

const execPromise = util.promisify(exec);

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize GitHub client
const octokit = new Octokit({
	auth: process.env.GITHUB_TOKEN
});

const GITHUB_OWNER = process.env.GITHUB_OWNER;
const GITHUB_REPO = process.env.GITHUB_REPO;
const GITHUB_BASE_BRANCH = process.env.GITHUB_BASE_BRANCH || 'main';

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Session configuration for AWS SSO
app.use(session({
	secret: process.env.SESSION_SECRET || 'your-secret-key-change-in-production',
	resave: false,
	saveUninitialized: false,
	cookie: {
		secure: process.env.NODE_ENV === 'production', // HTTPS only in production
		httpOnly: true,
		maxAge: 24 * 60 * 60 * 1000 // 24 hours
	}
}));

// Initialize Passport for AWS SSO
app.use(passport.initialize());
app.use(passport.session());

// Configure SAML strategy for AWS SSO
if (process.env.AWS_SSO_ENABLED === 'true') {
	passport.use(new SamlStrategy(
		{
			entryPoint: process.env.AWS_SSO_ENTRY_POINT,
			issuer: process.env.AWS_SSO_ISSUER || 'provisioning-ui',
			callbackUrl: process.env.AWS_SSO_CALLBACK_URL || `http://localhost:${PORT}/auth/callback`,
			cert: process.env.AWS_SSO_CERT, // X.509 certificate from AWS SSO
			identifierFormat: null
		},
		(profile, done) => {
			// Extract user information from SAML assertion
			return done(null, {
				id: profile.nameID,
				email: profile.email || profile.nameID,
				displayName: profile.displayName || profile.nameID,
				groups: profile.groups || []
			});
		}
	));

	passport.serializeUser((user, done) => {
		done(null, user);
	});

	passport.deserializeUser((user, done) => {
		done(null, user);
	});
}

// Authentication middleware
function ensureAuthenticated(req, res, next) {
	if (process.env.AWS_SSO_ENABLED !== 'true') {
		// SSO disabled, allow all requests
		return next();
	}
	
	if (req.isAuthenticated()) {
		return next();
	}
	
	res.status(401).json({ error: 'Authentication required' });
}

// Serve static files (only public routes)
app.use('/public', express.static('public'));

// Configuration
const TERRAFORM_BASE_PATH = path.join(__dirname, '..', 'live');
const REPO_PATH = path.join(__dirname, '..');
const git = simpleGit(REPO_PATH);

// Slack notification helper
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;

async function sendSlackNotification(message) {
	if (!SLACK_WEBHOOK_URL) {
		console.log('Slack webhook not configured, skipping notification');
		return;
	}
	
	try {
		await axios.post(SLACK_WEBHOOK_URL, message);
	} catch (error) {
		console.error('Failed to send Slack notification:', error.message);
	}
}

async function notifySlackProvisioning(customerName, environment, prUrl, user) {
	const envConfig = config.environments[environment];
	await sendSlackNotification({
		text: `🚀 New Customer Provisioning: ${customerName}`,
		blocks: [
			{
				type: 'header',
				text: {
					type: 'plain_text',
					text: '🚀 New Customer Provisioning Request'
				}
			},
			{
				type: 'section',
				fields: [
					{
						type: 'mrkdwn',
						text: `*Customer:*\n${customerName}`
					},
					{
						type: 'mrkdwn',
						text: `*Environment:*\n${envConfig ? envConfig.name : environment}`
					},
					{
						type: 'mrkdwn',
						text: `*AWS Account:*\n${envConfig ? envConfig.accountId : 'Unknown'}`
					},
					{
						type: 'mrkdwn',
						text: `*Requested By:*\n${user || 'Unknown'}`
					}
				]
			},
			{
				type: 'actions',
				elements: [
					{
						type: 'button',
						text: {
							type: 'plain_text',
							text: '📋 Review PR'
						},
						url: prUrl,
						style: 'primary'
					}
				]
			}
		]
	});
}

async function notifySlackError(operation, error, user) {
	await sendSlackNotification({
		text: `❌ Provisioning Error: ${operation}`,
		blocks: [
			{
				type: 'header',
				text: {
					type: 'plain_text',
					text: '❌ Provisioning Error'
				}
			},
			{
				type: 'section',
				fields: [
					{
						type: 'mrkdwn',
						text: `*Operation:*\n${operation}`
					},
					{
						type: 'mrkdwn',
						text: `*User:*\n${user || 'Unknown'}`
					}
				]
			},
			{
				type: 'section',
				text: {
					type: 'mrkdwn',
					text: `*Error:*\n\`\`\`${error}\`\`\``
				}
			}
		]
	});
}

// ==========================================
// AUTH ROUTES
// ==========================================

// SSO Login
app.get('/auth/login', (req, res, next) => {
	if (process.env.AWS_SSO_ENABLED !== 'true') {
		return res.redirect('/');
	}
	passport.authenticate('saml')(req, res, next);
});

// SSO Callback
app.post('/auth/callback',
	passport.authenticate('saml', { failureRedirect: '/auth/login-failed' }),
	(req, res) => {
		res.redirect('/');
	}
);

// Login failed
app.get('/auth/login-failed', (req, res) => {
	res.status(401).json({ error: 'SSO authentication failed' });
});

// Logout
app.get('/auth/logout', (req, res) => {
	req.logout(() => {
		res.redirect('/');
	});
});

// Get current user info
app.get('/auth/user', (req, res) => {
	if (process.env.AWS_SSO_ENABLED !== 'true') {
		return res.json({
			authenticated: true,
			ssoEnabled: false,
			user: { displayName: 'Local User', email: 'local@dev' }
		});
	}
	
	if (req.isAuthenticated()) {
		return res.json({
			authenticated: true,
			ssoEnabled: true,
			user: req.user
		});
	}
	
	res.json({ authenticated: false, ssoEnabled: true });
});

// Serve the app (protected by auth)
app.get('/', ensureAuthenticated, (req, res) => {
	res.sendFile(path.join(__dirname, 'public', 'index.html'));
});
app.use(ensureAuthenticated, express.static('public'));

// ==========================================
// API ROUTES (Protected)
// ==========================================

// API: Get available environments with account details
app.get('/api/environments', ensureAuthenticated, (req, res) => {
	const environments = Object.keys(config.environments).map(key => ({
		id: key,
		...config.environments[key]
	}));
	res.json({ environments });
});

// API: Get current configuration for an environment
app.get('/api/config/:environment/:stack', ensureAuthenticated, (req, res) => {
	const { environment, stack } = req.params;
	
	if (!config.environments[environment]) {
		return res.status(400).json({ error: 'Invalid environment' });
	}
	
	if (!['compute', 'alb', 'rds'].includes(stack)) {
		return res.status(400).json({ error: 'Invalid stack' });
	}
	
	const tfvarsPath = path.join(TERRAFORM_BASE_PATH, environment, stack, 'terraform.auto.tfvars');
	
	try {
		const content = fs.readFileSync(tfvarsPath, 'utf8');
		res.json({ content });
	} catch (error) {
		res.status(500).json({ error: error.message });
	}
});

// API: Generate Terraform configuration for new customer
app.post('/api/generate-config', ensureAuthenticated, (req, res) => {
	const { customerName, environment, instanceType, rootEbsSize, subnetId, amiId, hostHeader, backendPort, priority, rdsInstanceClass, rdsStorage } = req.body;
	
	// Validate inputs
	if (!customerName || !environment) {
		return res.status(400).json({ error: 'Customer name and environment are required' });
	}
	
	if (!config.environments[environment]) {
		return res.status(400).json({ error: 'Invalid environment' });
	}
	
	const envConfig = config.environments[environment];
	const sanitizedName = customerName.toLowerCase().replace(/[^a-z0-9-]/g, '-');
	const accountId = envConfig.accountId;
	
	// Get KMS key - handle Terraform references for dev environment
	let kmsKeyArn = config.kmsKeys[accountId] || config.kmsKeys['109743757398'];
	
	// For dev environment, use Terraform reference since key is managed by Terraform
	if (environment === 'cri-ct-rv-dev' && kmsKeyArn === 'aws_kms_key.this.arn') {
		kmsKeyArn = 'aws_kms_key.this.arn'; // Keep as Terraform reference
	}
	
	// Generate EC2 configuration
	const ec2Config = `
  "${sanitizedName}" = {
    ami_id               = "${amiId || config.defaults.amiId}"
    instance_type        = "${instanceType || config.defaults.instanceType}"
    subnet_id            = "${subnetId || (config.subnets[environment] ? config.subnets[environment][0] : 'subnet-REPLACE-ME')}"
    root_ebs_size        = ${rootEbsSize || config.defaults.rootEbsSize}
    root_ebs_type        = "${config.defaults.rootEbsType}"
    root_ebs_kms_key_arn = "${kmsKeyArn}"
    deletion_protection  = true
    user_data = <<-EOF
      <powershell>
      $desiredName = "${sanitizedName}"
      if ($env:COMPUTERNAME -ne $desiredName) {
        Rename-Computer -NewName $desiredName -Force -Restart
      }
      </powershell>
    EOF
    tags = {
      "Name" = "${sanitizedName}"
      "Customer" = "${customerName}"
      "Environment" = "${environment}"
      "ManagedBy" = "Terraform"
      "ProvisionedDate" = "${new Date().toISOString().split('T')[0]}"
    }
  }`;
	
	// Generate ALB configuration
	const albConfig = `
  "${sanitizedName}" = {
    instance_key   = "${sanitizedName}"
    host_headers   = ["${hostHeader || `${sanitizedName}.hosted.reflectsystems.com`}"]
    priority       = ${priority || 200}
    backend_port   = ${backendPort || config.defaults.backendPort}
    backend_proto  = "${config.defaults.backendProto}"
    health_path    = "${config.defaults.healthPath}"
    health_matcher = "${config.defaults.healthMatcher}"
  }`;
	
	// Generate RDS configuration (optional)
	let rdsConfig = null;
	if (rdsInstanceClass && rdsStorage) {
		rdsConfig = `
  "${sanitizedName}" = {
    identifier                    = "rv-${environment.split('-').pop()}-${sanitizedName}-rds"
    instance_class                = "${rdsInstanceClass}"
    kms_key_id                    = "${kmsKeyArn}"
    allocated_storage             = ${rdsStorage}
    max_allocated_storage         = ${rdsStorage * 5}
    monitoring_role_name          = "sqlserver-rds-${sanitizedName}-monitoring-role"
    backup_retention_period       = 30
    manage_master_user_password   = true
    master_user_secret_kms_key_id = "${kmsKeyArn}"
  }`;
	}
	
	res.json({
		customerName,
		sanitizedName,
		environment,
		accountId,
		ec2Config,
		albConfig,
		rdsConfig,
		instructions: {
			compute: `Add this to ${environment}/compute/terraform.auto.tfvars under prod1_ec2_instances`,
			alb: `Add this to ${environment}/alb/terraform.auto.tfvars under app_routes`,
			rds: rdsConfig ? `Add this to ${environment}/rds/terraform.auto.tfvars under rds_instances` : null
		},
		requireApproval: envConfig.requireApproval,
		autoApply: envConfig.autoApply
	});
});

// Helper: Create GitHub branch and commit changes
async function createGitHubBranch(branchName, files, commitMessage) {
	try {
		// Get the latest commit SHA from base branch
		const { data: refData } = await octokit.git.getRef({
			owner: GITHUB_OWNER,
			repo: GITHUB_REPO,
			ref: `heads/${GITHUB_BASE_BRANCH}`
		});
		
		const baseSha = refData.object.sha;
		
		// Create new branch
		await octokit.git.createRef({
			owner: GITHUB_OWNER,
			repo: GITHUB_REPO,
			ref: `refs/heads/${branchName}`,
			sha: baseSha
		});
		
		// Update files
		for (const file of files) {
			// Get current file content to get its SHA
			let fileSha;
			try {
				const { data: fileData } = await octokit.repos.getContent({
					owner: GITHUB_OWNER,
					repo: GITHUB_REPO,
					path: file.path,
					ref: branchName
				});
				fileSha = fileData.sha;
			} catch (error) {
				// File doesn't exist, that's okay
				fileSha = null;
			}
			
			// Update or create file
			await octokit.repos.createOrUpdateFileContents({
				owner: GITHUB_OWNER,
				repo: GITHUB_REPO,
				path: file.path,
				message: commitMessage,
				content: Buffer.from(file.content).toString('base64'),
				branch: branchName,
				sha: fileSha
			});
		}
		
		return { success: true, branchName };
	} catch (error) {
		console.error('Error creating GitHub branch:', error);
		throw error;
	}
}

// Helper: Create GitHub Pull Request
async function createPullRequest(branchName, title, body) {
	try {
		const { data: pr } = await octokit.pulls.create({
			owner: GITHUB_OWNER,
			repo: GITHUB_REPO,
			title,
			head: branchName,
			base: GITHUB_BASE_BRANCH,
			body
		});
		
		return {
			success: true,
			prNumber: pr.number,
			prUrl: pr.html_url
		};
	} catch (error) {
		console.error('Error creating pull request:', error);
		throw error;
	}
}

// API: Create Pull Request with Terraform changes
app.post('/api/create-pr', ensureAuthenticated, async (req, res) => {
	const { customerName, sanitizedName, environment, ec2Config, albConfig, rdsConfig } = req.body;
	
	if (!config.environments[environment]) {
		return res.status(400).json({ error: 'Invalid environment' });
	}
	
	const userName = req.user ? (req.user.displayName || req.user.email) : 'Unknown User';
	
	try {
		const branchName = `provision-${sanitizedName}-${Date.now()}`;
		const envConfig = config.environments[environment];
		
		// Read current tfvars files
		const computePath = `live/${environment}/compute/terraform.auto.tfvars`;
		const albPath = `live/${environment}/alb/terraform.auto.tfvars`;
		const rdsPath = `live/${environment}/rds/terraform.auto.tfvars`;
		
		const computeContent = fs.readFileSync(path.join(REPO_PATH, computePath), 'utf8');
		const albContent = fs.readFileSync(path.join(REPO_PATH, albPath), 'utf8');
		
		// Prepare updated files
		const files = [
			{
				path: computePath,
				content: computeContent + '\n' + ec2Config
			},
			{
				path: albPath,
				content: albContent + '\n' + albConfig
			}
		];
		
		// Add RDS if provided
		if (rdsConfig) {
			const rdsContent = fs.readFileSync(path.join(REPO_PATH, rdsPath), 'utf8');
			files.push({
				path: rdsPath,
				content: rdsContent + '\n' + rdsConfig
			});
		}
		
		// Create branch and commit
		const commitMessage = `Provision new customer: ${customerName} (${sanitizedName})

Environment: ${environment} (${envConfig.name})
AWS Account: ${envConfig.accountId}
Stacks: Compute, ALB${rdsConfig ? ', RDS' : ''}
Requested by: ${userName}

Auto-generated by ReflectView Provisioning UI`;
		
		await createGitHubBranch(branchName, files, commitMessage);
		
		// Create Pull Request
		const prTitle = `🚀 Provision Customer: ${customerName}`;
		const prBody = `## New Customer Provisioning

**Customer Name:** ${customerName}  
**Sanitized Name:** \`${sanitizedName}\`  
**Environment:** ${environment} (${envConfig.name})  
**AWS Account:** ${envConfig.accountId}  
**Requested By:** ${userName}

### Changes

- ✅ **EC2 Instance** (Compute stack)
- ✅ **ALB Route** (ALB stack)
${rdsConfig ? '- ✅ **RDS Database** (RDS stack)' : ''}

### Terraform Apply Order

1. \`cd live/${environment}/compute && terraform plan && terraform apply\`
2. \`cd live/${environment}/alb && terraform plan && terraform apply\`
${rdsConfig ? `3. \`cd live/${environment}/rds && terraform plan && terraform apply\`` : ''}

### Configuration Details

<details>
<summary>EC2 Configuration</summary>

\`\`\`hcl
${ec2Config}
\`\`\`
</details>

<details>
<summary>ALB Configuration</summary>

\`\`\`hcl
${albConfig}
\`\`\`
</details>

${rdsConfig ? `<details>
<summary>RDS Configuration</summary>

\`\`\`hcl
${rdsConfig}
\`\`\`
</details>` : ''}

---

**Provisioned by:** ${userName}  
**Date:** ${new Date().toISOString()}  
${envConfig.requireApproval ? '**⚠️ Requires approval before merge**' : ''}`;
		
		const prResult = await createPullRequest(branchName, prTitle, prBody);
		
		// Send Slack notification
		await notifySlackProvisioning(customerName, environment, prResult.prUrl, userName);
		
		res.json({
			success: true,
			message: 'Pull request created successfully',
			branchName,
			prNumber: prResult.prNumber,
			prUrl: prResult.prUrl,
			requireApproval: envConfig.requireApproval
		});
	} catch (error) {
		console.error('Error creating PR:', error);
		
		// Send error notification to Slack
		await notifySlackError('Create PR', error.message, userName);
		
		res.status(500).json({
			success: false,
			error: error.message
		});
	}
});

// API: Apply configuration (writes to tfvars and optionally runs terraform)
app.post('/api/apply-config', ensureAuthenticated, async (req, res) => {
	const { environment, stack, config, autoApply } = req.body;
	
	if (!ENVIRONMENTS.includes(environment)) {
		return res.status(400).json({ error: 'Invalid environment' });
	}
	
	if (!['compute', 'alb', 'rds'].includes(stack)) {
		return res.status(400).json({ error: 'Invalid stack' });
	}
	
	const tfvarsPath = path.join(TERRAFORM_BASE_PATH, environment, stack, 'terraform.auto.tfvars');
	const stackPath = path.join(TERRAFORM_BASE_PATH, environment, stack);
	
	try {
		// Read current tfvars
		let currentContent = fs.readFileSync(tfvarsPath, 'utf8');
		
		// Append new configuration
		// This is a simple append - in production, you'd want to parse and merge properly
		const updatedContent = currentContent + '\n' + config;
		
		// Write updated tfvars
		fs.writeFileSync(tfvarsPath, updatedContent, 'utf8');
		
		const result = {
			success: true,
			message: `Configuration added to ${stack} stack`,
			tfvarsPath
		};
		
		// Optionally run terraform plan/apply
		if (autoApply) {
			try {
				// Run terraform plan
				const { stdout: planOutput, stderr: planError } = await execPromise('terraform plan', { cwd: stackPath });
				result.planOutput = planOutput;
				result.planError = planError;
				
				// Note: In production, you'd want manual approval before apply
				// For now, we just return the plan output
				result.message += '. Review the plan output before applying.';
			} catch (error) {
				result.terraformError = error.message;
			}
		}
		
		res.json(result);
	} catch (error) {
		res.status(500).json({ error: error.message });
	}
});

// API: Run terraform command
app.post('/api/terraform/:command', ensureAuthenticated, async (req, res) => {
	const { command } = req.params;
	const { environment, stack } = req.body;
	
	if (!['plan', 'apply', 'destroy'].includes(command)) {
		return res.status(400).json({ error: 'Invalid terraform command' });
	}
	
	if (!ENVIRONMENTS.includes(environment)) {
		return res.status(400).json({ error: 'Invalid environment' });
	}
	
	if (!['compute', 'alb', 'rds'].includes(stack)) {
		return res.status(400).json({ error: 'Invalid stack' });
	}
	
	const stackPath = path.join(TERRAFORM_BASE_PATH, environment, stack);
	
	try {
		const terraformCommand = command === 'apply' ? 'terraform apply -auto-approve' : `terraform ${command}`;
		const { stdout, stderr } = await execPromise(terraformCommand, { cwd: stackPath });
		
		res.json({
			success: true,
			stdout,
			stderr
		});
	} catch (error) {
		res.status(500).json({
			success: false,
			error: error.message,
			stdout: error.stdout,
			stderr: error.stderr
		});
	}
});

// Start server
app.listen(PORT, () => {
	console.log(`ReflectView Provisioning UI running on http://localhost:${PORT}`);
});
