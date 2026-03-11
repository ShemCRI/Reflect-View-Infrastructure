/**
 * Azure AD Domain Join Module
 * 
 * This module creates an SSM document and association to automatically
 * join Windows EC2 instances to an Azure AD DS domain.
 *
 * Prerequisites:
 * - SSM Parameter Store entries for username (String) and password (SecureString)
 * - Username must be in UPN format (e.g., user@domain.com)
 * - EC2 instances must have IAM permissions: ssm:GetParameter on the credential parameters
 * - Target instances must have the SSM agent installed and be registered with SSM
 */

resource "aws_ssm_document" "azure_ad_join" {
  name          = "${var.document_name_prefix}-${var.environment}"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Join Windows instances to Azure AD DS domain (${var.domain_name})"
    parameters = {
      DomainName = {
        type    = "String"
        default = var.domain_name
      }
      OUPath = {
        type    = "String"
        default = var.ou_path
      }
      Dns1 = {
        type    = "String"
        default = try(var.dns_ips[0], "")
      }
      Dns2 = {
        type    = "String"
        default = try(var.dns_ips[1], "")
      }
      UsernameParameterName = {
        type        = "String"
        description = "SSM Parameter Store name containing the domain join username"
      }
      PasswordParameterName = {
        type        = "String"
        description = "SSM Parameter Store name containing the domain join password (SecureString)"
      }
    }
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "domainJoinAzureAdDs"
        inputs = {
          runCommand = [
            "# Fetch credentials from SSM Parameter Store at runtime",
            "$domainUser = (Get-SSMParameterValue -Name '{{UsernameParameterName}}' -WithDecryption $true).Parameters[0].Value.Trim()",
            "$domainPassword = (Get-SSMParameterValue -Name '{{PasswordParameterName}}' -WithDecryption $true).Parameters[0].Value.Trim()",
            "",
            "# Configure DNS",
            "$dnsServers = @('{{Dns1}}', '{{Dns2}}')",
            "$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and -not $_.Virtual } | Sort-Object -Property ifIndex | Select-Object -First 1",
            "if ($null -eq $adapter) { throw 'No active network adapter found for DNS configuration.' }",
            "Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers",
            "",
            "# Build credential and join domain",
            "$secPassword = ConvertTo-SecureString -String $domainPassword -AsPlainText -Force",
            "$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $domainUser, $secPassword",
            "Add-Computer -DomainName '{{DomainName}}' -OUPath '{{OUPath}}' -Credential $credential -Force -ErrorAction Stop",
            "",
            "# Reboot to complete domain join",
            "Restart-Computer -Force"
          ]
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Purpose     = "Azure AD DS Domain Join"
  }
}

resource "aws_ssm_association" "azure_ad_join" {
  name = aws_ssm_document.azure_ad_join.name

  compliance_severity = "HIGH"

  parameters = {
    UsernameParameterName = var.username_parameter_name
    PasswordParameterName = var.password_parameter_name
  }

  targets {
    key    = "tag:${var.target_tag_key}"
    values = [var.target_tag_value]
  }
}

