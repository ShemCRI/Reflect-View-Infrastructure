// Environment and AWS Account Configuration
module.exports = {
	// Environment to AWS Account mapping
	environments: {
		'cri-ct-rv-dev': {
			name: 'Development',
			accountId: '164804042272',
			region: 'us-east-1',
			requireApproval: false,
			autoApply: true,
			description: 'Development environment for testing'
		},
		'cri-ct-rv-staging': {
			name: 'Staging',
			accountId: 'STAGING_ACCOUNT_ID', // Replace with actual staging account
			region: 'us-east-1',
			requireApproval: true,
			autoApply: false,
			description: 'Staging environment for pre-production testing'
		},
		'cri-ct-rv-prod1': {
			name: 'Production 1',
			accountId: '109743757398',
			region: 'us-east-1',
			requireApproval: true,
			autoApply: false,
			description: 'Production environment 1'
		},
		'cri-ct-rv-prod2': {
			name: 'Production 2',
			accountId: 'PROD2_ACCOUNT_ID', // Replace with actual prod2 account
			region: 'us-east-1',
			requireApproval: true,
			autoApply: false,
			description: 'Production environment 2'
		},
		'cri-ct-rv-prod3': {
			name: 'Production 3',
			accountId: 'PROD3_ACCOUNT_ID', // Replace with actual prod3 account
			region: 'us-east-1',
			requireApproval: true,
			autoApply: false,
			description: 'Production environment 3'
		}
	},

	// Shared Services Account (for Terraform state)
	sharedServicesAccount: '530258393729',

	// Default values for provisioning
	defaults: {
		amiId: 'ami-0159172a5a821bafd', // Windows Server 2022
		instanceType: 't3.medium',
		rootEbsSize: 80,
		rootEbsType: 'gp3',
		backendPort: 443,
		backendProto: 'HTTPS',
		healthPath: '/health',
		healthMatcher: '200',
		
		// Azure AD Domain Join settings
		azureAdDomainName: 'hosted.reflectsystems.com',
		azureAdDnsIps: ['10.0.10.5', '10.0.10.4'],
		azureAdOuPath: 'OU=AADDC Computers,DC=hosted,DC=reflectsystems,DC=com',
		
		// DSC Configuration
		dscNodeConfigurationName: 'reflectview_saas_rv3_UTC_TLSHardened_2022.localhost'
	},

	// KMS Key IDs per account
	// Note: Dev environment uses Terraform-managed KMS key (see live/cri-ct-rv-dev/rds/kms.tf)
	// For dev, we'll use a reference to the Terraform resource instead of hardcoding
	kmsKeys: {
		'164804042272': 'aws_kms_key.this.arn', // Dev: Reference to Terraform-managed key
		'109743757398': 'arn:aws:kms:us-east-1:109743757398:key/73e39090-a5ae-4eb6-98b6-a0d04b1d6f89'
		// Add other account KMS keys as needed
	},

	// Subnet IDs per environment (RapidScale-approved private subnets)
	subnets: {
		'cri-ct-rv-dev': [
			'subnet-dev-private-1',
			'subnet-dev-private-2',
			'subnet-dev-private-3'
		],
		'cri-ct-rv-prod1': [
			'subnet-08476614697a4c96b',
			'subnet-prod1-private-2',
			'subnet-prod1-private-3'
		]
		// Add other environment subnets as needed
	},

	// ALB priority ranges per environment
	albPriorityRanges: {
		'cri-ct-rv-dev': { min: 200, max: 1000 },
		'cri-ct-rv-staging': { min: 1001, max: 2000 },
		'cri-ct-rv-prod1': { min: 200, max: 1000 },
		'cri-ct-rv-prod2': { min: 200, max: 1000 },
		'cri-ct-rv-prod3': { min: 200, max: 1000 }
	}
};
