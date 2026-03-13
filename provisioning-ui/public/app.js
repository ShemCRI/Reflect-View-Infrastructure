const API_BASE = 'http://localhost:3000/api';

let generatedConfig = null;
let environmentsData = {};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
	loadEnvironments();
	setupEventListeners();
});

function setupEventListeners() {
	document.getElementById('customerName').addEventListener('input', updateSanitizedName);
}

function updateSanitizedName() {
	const customerName = document.getElementById('customerName').value;
	const sanitized = customerName.toLowerCase().replace(/[^a-z0-9-]/g, '-');
	document.getElementById('sanitizedName').textContent = sanitized || '-';
	
	// Auto-update host header
	if (sanitized) {
		document.getElementById('hostHeader').value = `${sanitized}.hosted.reflectsystems.com`;
	}
}

function updateEnvironmentInfo() {
	const envId = document.getElementById('environment').value;
	if (!envId || !environmentsData[envId]) {
		document.getElementById('environmentInfo').style.display = 'none';
		return;
	}
	
	const env = environmentsData[envId];
	document.getElementById('accountId').textContent = env.accountId;
	document.getElementById('region').textContent = env.region;
	document.getElementById('envDescription').textContent = env.description;
	
	const badge = document.getElementById('approvalBadge');
	if (env.requireApproval) {
		badge.textContent = '⚠️ Requires Approval';
		badge.className = 'badge approval-required';
	} else {
		badge.textContent = '✅ Auto-Apply Enabled';
		badge.className = 'badge auto-apply';
	}
	
	document.getElementById('environmentInfo').style.display = 'block';
}

async function loadEnvironments() {
	try {
		const response = await fetch(`${API_BASE}/environments`);
		const data = await response.json();
		
		const select = document.getElementById('environment');
		data.environments.forEach(env => {
			environmentsData[env.id] = env;
			const option = document.createElement('option');
			option.value = env.id;
			option.textContent = `${env.name} (${env.accountId})`;
			select.appendChild(option);
		});
	} catch (error) {
		console.error('Error loading environments:', error);
		alert('Failed to load environments. Make sure the server is running.');
	}
}

function nextStep(stepNumber) {
	// Validate current step
	const currentStep = document.querySelector('.step.active');
	const inputs = currentStep.querySelectorAll('input[required], select[required]');
	let valid = true;
	
	inputs.forEach(input => {
		if (!input.value) {
			valid = false;
			input.style.borderColor = '#ef4444';
		} else {
			input.style.borderColor = '#e0e0e0';
		}
	});
	
	if (!valid) {
		alert('Please fill in all required fields');
		return;
	}
	
	// Hide current step
	currentStep.classList.remove('active');
	
	// Show next step
	document.getElementById(`step${stepNumber}`).classList.add('active');
	
	// Scroll to top
	window.scrollTo({ top: 0, behavior: 'smooth' });
}

function prevStep(stepNumber) {
	document.querySelector('.step.active').classList.remove('active');
	document.getElementById(`step${stepNumber}`).classList.add('active');
	window.scrollTo({ top: 0, behavior: 'smooth' });
}

function toggleRdsFields() {
	const includeRds = document.getElementById('includeRds').checked;
	document.getElementById('rdsFields').style.display = includeRds ? 'block' : 'none';
}

async function generateConfig() {
	const customerName = document.getElementById('customerName').value;
	const environment = document.getElementById('environment').value;
	const instanceType = document.getElementById('instanceType').value;
	const rootEbsSize = document.getElementById('rootEbsSize').value;
	const subnetId = document.getElementById('subnetId').value;
	const amiId = document.getElementById('amiId').value;
	const hostHeader = document.getElementById('hostHeader').value;
	const backendPort = document.getElementById('backendPort').value;
	const priority = document.getElementById('priority').value;
	
	const includeRds = document.getElementById('includeRds').checked;
	const rdsInstanceClass = includeRds ? document.getElementById('rdsInstanceClass').value : null;
	const rdsStorage = includeRds ? document.getElementById('rdsStorage').value : null;
	
	try {
		const response = await fetch(`${API_BASE}/generate-config`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				customerName,
				environment,
				instanceType,
				rootEbsSize,
				subnetId,
				amiId,
				hostHeader,
				backendPort,
				priority,
				rdsInstanceClass,
				rdsStorage
			})
		});
		
		generatedConfig = await response.json();
		
		// Display configurations
		document.getElementById('ec2ConfigPreview').textContent = generatedConfig.ec2Config;
		document.getElementById('albConfigPreview').textContent = generatedConfig.albConfig;
		
		if (generatedConfig.rdsConfig) {
			document.getElementById('rdsConfigSection').style.display = 'block';
			document.getElementById('rdsConfigPreview').textContent = generatedConfig.rdsConfig;
		} else {
			document.getElementById('rdsConfigSection').style.display = 'none';
		}
		
		// Display instructions
		const instructionsList = document.getElementById('instructionsList');
		instructionsList.innerHTML = '';
		
		const instructions = [
			`<strong>Compute Stack:</strong> ${generatedConfig.instructions.compute}`,
			`<strong>ALB Stack:</strong> ${generatedConfig.instructions.alb}`
		];
		
		if (generatedConfig.instructions.rds) {
			instructions.push(`<strong>RDS Stack:</strong> ${generatedConfig.instructions.rds}`);
		}
		
		instructions.push(
			'Run <code>terraform plan</code> in each stack directory to preview changes',
			'Run <code>terraform apply</code> to provision the infrastructure',
			'<strong>Apply order:</strong> Compute → ALB → RDS (if applicable)'
		);
		
		instructions.forEach(instruction => {
			const li = document.createElement('li');
			li.innerHTML = instruction;
			instructionsList.appendChild(li);
		});
		
		// Move to review step
		nextStep(5);
	} catch (error) {
		console.error('Error generating config:', error);
		alert('Failed to generate configuration. Please try again.');
	}
}

function copyToClipboard() {
	let text = '# EC2 Configuration (Compute Stack)\n';
	text += generatedConfig.ec2Config + '\n\n';
	text += '# ALB Configuration (ALB Stack)\n';
	text += generatedConfig.albConfig + '\n\n';
	
	if (generatedConfig.rdsConfig) {
		text += '# RDS Configuration (RDS Stack)\n';
		text += generatedConfig.rdsConfig + '\n';
	}
	
	navigator.clipboard.writeText(text).then(() => {
		alert('✅ Configuration copied to clipboard!');
	}).catch(err => {
		console.error('Failed to copy:', err);
		alert('Failed to copy to clipboard. Please copy manually.');
	});
}

async function createPullRequest() {
	if (!generatedConfig) {
		alert('Please generate configuration first');
		return;
	}
	
	const resultDiv = document.getElementById('prResult');
	resultDiv.style.display = 'block';
	resultDiv.className = 'result';
	resultDiv.innerHTML = '<p>⏳ Creating pull request...</p>';
	
	try {
		const response = await fetch(`${API_BASE}/create-pr`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				customerName: generatedConfig.customerName,
				sanitizedName: generatedConfig.sanitizedName,
				environment: generatedConfig.environment,
				ec2Config: generatedConfig.ec2Config,
				albConfig: generatedConfig.albConfig,
				rdsConfig: generatedConfig.rdsConfig
			})
		});
		
		const result = await response.json();
		
		if (result.success) {
			resultDiv.className = 'result success';
			resultDiv.innerHTML = `
				<h3>✅ Pull Request Created Successfully!</h3>
				<p><strong>Branch:</strong> ${result.branchName}</p>
				<p><strong>PR #${result.prNumber}:</strong> <a href="${result.prUrl}" target="_blank">${result.prUrl}</a></p>
				${result.requireApproval ? '<p><strong>⚠️ This PR requires approval before it can be merged.</strong></p>' : ''}
				<p style="margin-top: 15px;">
					<strong>Next Steps:</strong><br>
					1. Review the pull request on GitHub<br>
					2. ${result.requireApproval ? 'Get approval from team members<br>3. ' : ''}Merge the pull request<br>
					${result.requireApproval ? '4' : '3'}. Run terraform apply in each stack directory
				</p>
			`;
		} else {
			throw new Error(result.error || 'Failed to create pull request');
		}
	} catch (error) {
		console.error('Error creating PR:', error);
		resultDiv.className = 'result error';
		resultDiv.innerHTML = `
			<h3>❌ Error Creating Pull Request</h3>
			<p>${error.message}</p>
			<p>Please check the server logs and GitHub token configuration.</p>
		`;
	}
}

async function applyConfig() {
	if (!confirm('This will write the configuration to Terraform files. Continue?')) {
		return;
	}
	
	const environment = document.getElementById('environment').value;
	const resultDiv = document.getElementById('applyResult');
	resultDiv.style.display = 'block';
	resultDiv.className = 'result';
	resultDiv.innerHTML = '<p>⏳ Applying configuration...</p>';
	
	try {
		// Apply compute stack
		const computeResponse = await fetch(`${API_BASE}/apply-config`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				environment,
				stack: 'compute',
				config: generatedConfig.ec2Config,
				autoApply: false
			})
		});
		
		const computeResult = await computeResponse.json();
		
		// Apply ALB stack
		const albResponse = await fetch(`${API_BASE}/apply-config`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				environment,
				stack: 'alb',
				config: generatedConfig.albConfig,
				autoApply: false
			})
		});
		
		const albResult = await albResponse.json();
		
		// Apply RDS stack if applicable
		let rdsResult = null;
		if (generatedConfig.rdsConfig) {
			const rdsResponse = await fetch(`${API_BASE}/apply-config`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					environment,
					stack: 'rds',
					config: generatedConfig.rdsConfig,
					autoApply: false
				})
			});
			
			rdsResult = await rdsResponse.json();
		}
		
		// Display results
		resultDiv.className = 'result success';
		resultDiv.innerHTML = `
			<h3>✅ Configuration Applied Successfully!</h3>
			<p><strong>Compute Stack:</strong> ${computeResult.message}</p>
			<p><strong>ALB Stack:</strong> ${albResult.message}</p>
			${rdsResult ? `<p><strong>RDS Stack:</strong> ${rdsResult.message}</p>` : ''}
			<p style="margin-top: 15px;">
				<strong>Next Steps:</strong><br>
				1. Navigate to each stack directory<br>
				2. Run <code>terraform plan</code> to review changes<br>
				3. Run <code>terraform apply</code> to provision infrastructure
			</p>
		`;
	} catch (error) {
		console.error('Error applying config:', error);
		resultDiv.className = 'result error';
		resultDiv.innerHTML = `
			<h3>❌ Error Applying Configuration</h3>
			<p>${error.message}</p>
			<p>Please check the server logs and try again.</p>
		`;
	}
}
