/**
 * Azure Automation DSC Registration Module
 * 
 * This module creates an SSM document and association to automatically
 * register Windows EC2 instances with Azure Automation DSC.
 *
 * Prerequisites:
 * - SSM Parameter Store entries for:
 *   - Registration URL (String): Azure Automation account DSC endpoint URL
 *   - Registration Key (SecureString): Primary or secondary registration key
 * - EC2 instances must have IAM permissions: ssm:GetParameter on the credential parameters
 * - Target instances must have the SSM agent installed and be registered with SSM
 * - Windows PowerShell 5.1+ (included in Windows Server 2016+)
 */

resource "aws_ssm_document" "dsc_registration" {
  name          = "${var.document_name_prefix}-${var.environment}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Register Windows instances with Azure Automation DSC (${var.environment})"
    parameters = {
      RegistrationUrlParameter = {
        type        = "String"
        description = "SSM Parameter Store name containing the Azure Automation DSC registration URL"
      }
      RegistrationKeyParameter = {
        type        = "String"
        description = "SSM Parameter Store name containing the Azure Automation DSC registration key (SecureString)"
      }
      NodeConfigurationName = {
        type        = "String"
        description = "DSC node configuration to apply"
        default     = var.node_configuration_name
      }
      ConfigurationMode = {
        type        = "String"
        description = "LCM configuration mode"
        default     = var.configuration_mode
      }
      ConfigurationModeFrequencyMins = {
        type        = "String"
        description = "Frequency (mins) to check configuration compliance"
        default     = tostring(var.configuration_mode_frequency_mins)
      }
      RefreshFrequencyMins = {
        type        = "String"
        description = "Frequency (mins) to check for configuration updates"
        default     = tostring(var.refresh_frequency_mins)
      }
      RebootIfNeeded = {
        type        = "String"
        description = "Allow automatic reboots if needed"
        default     = var.reboot_if_needed ? "$true" : "$false"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "registerAzureAutomationDsc"
        inputs = {
          runCommand = [
            "# Azure Automation DSC Registration Script",
            "# Fetches registration details from SSM Parameter Store and registers this node",
            "",
            "$ErrorActionPreference = 'Stop'",
            "",
            "# Fetch registration details from SSM Parameter Store",
            "Write-Host 'Fetching registration URL from SSM Parameter Store...'",
            "$RegistrationUrl = (Get-SSMParameterValue -Name '{{RegistrationUrlParameter}}' -WithDecryption $false).Parameters[0].Value.Trim()",
            "",
            "Write-Host 'Fetching registration key from SSM Parameter Store...'",
            "$RegistrationKey = (Get-SSMParameterValue -Name '{{RegistrationKeyParameter}}' -WithDecryption $true).Parameters[0].Value.Trim()",
            "",
            "if ([string]::IsNullOrWhiteSpace($RegistrationUrl)) {",
            "    throw 'Registration URL is empty. Check the SSM parameter.'",
            "}",
            "if ([string]::IsNullOrWhiteSpace($RegistrationKey)) {",
            "    throw 'Registration key is empty. Check the SSM parameter.'",
            "}",
            "",
            "# Configuration parameters",
            "$NodeConfigurationName = '{{NodeConfigurationName}}'",
            "$ConfigurationMode = '{{ConfigurationMode}}'",
            "$ConfigModeFreqMins = [int]'{{ConfigurationModeFrequencyMins}}'",
            "$RefreshFreqMins = [int]'{{RefreshFrequencyMins}}'",
            "$RebootIfNeeded = {{RebootIfNeeded}}",
            "",
            "# Define the DSC metaconfiguration (matches proven working script)",
            "[DSCLocalConfigurationManager()]",
            "configuration MetaConfig",
            "{",
            "    Node 'localhost'",
            "    {",
            "        Settings",
            "        {",
            "            RefreshMode = 'Pull'",
            "            RefreshFrequencyMins = $RefreshFreqMins",
            "            ConfigurationMode = $ConfigurationMode",
            "            ConfigurationModeFrequencyMins = $ConfigModeFreqMins",
            "            RebootNodeIfNeeded = $RebootIfNeeded",
            "        }",
            "        ConfigurationRepositoryWeb AzureAutomation",
            "        {",
            "            ServerUrl = $RegistrationUrl",
            "            RegistrationKey = $RegistrationKey",
            "            ConfigurationNames = @($NodeConfigurationName)",
            "            AllowUnsecureConnection = $false",
            "        }",
            "        ReportServerWeb AzureAutomationReport",
            "        {",
            "            ServerUrl = $RegistrationUrl",
            "            RegistrationKey = $RegistrationKey",
            "            AllowUnsecureConnection = $false",
            "        }",
            "    }",
            "}",
            "",
            "# Generate the MOF file",
            "Write-Host 'Generating DSC metaconfiguration MOF...'",
            "$tempPath = Join-Path $env:TEMP 'DscMetaConfig'",
            "if (Test-Path $tempPath) { Remove-Item -Path $tempPath -Recurse -Force }",
            "New-Item -ItemType Directory -Path $tempPath -Force | Out-Null",
            "",
            "MetaConfig -OutputPath $tempPath",
            "",
            "# Apply the metaconfiguration to register with Azure Automation DSC",
            "Write-Host 'Applying DSC metaconfiguration to register with Azure Automation...'",
            "Set-DscLocalConfigurationManager -Path $tempPath -Force -Verbose",
            "",
            "# Verify registration",
            "Write-Host 'Verifying DSC registration...'",
            "$lcm = Get-DscLocalConfigurationManager",
            "Write-Host \"Refresh Mode: $($lcm.RefreshMode)\"",
            "Write-Host \"Configuration Mode: $($lcm.ConfigurationMode)\"",
            "Write-Host \"Refresh Frequency: $($lcm.RefreshFrequencyMins) mins\"",
            "",
            "# Cleanup",
            "Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue",
            "",
            "Write-Host 'Azure Automation DSC registration completed successfully.'"
          ]
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Purpose     = "Azure Automation DSC Registration"
  }
}

resource "aws_ssm_association" "dsc_registration" {
  name = aws_ssm_document.dsc_registration.name

  compliance_severity = "HIGH"

  parameters = {
    RegistrationUrlParameter = var.registration_url_parameter
    RegistrationKeyParameter = var.registration_key_parameter
  }

  targets {
    key    = "tag:${var.target_tag_key}"
    values = [var.target_tag_value]
  }
}

