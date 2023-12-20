<#
  .SYNOPSIS
  Check for any failing Proactive Remediation Scripts and alert the Support Team if any found.

  .DESCRIPTION
  Check for any failing Proactive Remediation Scripts with a failure rate >= 30% and alert the Support Team if any found.  

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "From": {
                "DisplayName": "Sender mail address"
            },
            "To": {
                "DisplayName": "Send mail to"
            }
        }
    }

  .NOTES
  Permissions: 
  MS Graph (API)
  - Mail.Send
  - DeviceManagementConfiguration.Read
  
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [bool] $sendEmailIfFound = $true,
    [string] $From = "reports@contoso.com",
    [string] $To = "support@glueckkanja.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph


## Graph Query : "GET https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?$expand=assignments,runSummary"
## to grab all of the current Proactive Remediation Script packages
$ProRemScripts = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceHealthScripts" -UriQueryRaw '$expand=assignments,runSummary' -Beta

if ($null -eq $ProRemScripts) {
    throw "## No Proactive Remediation Scripts have been found. Terminating..."
}

$results = @()

## Calculate the totalDeviceCount and then calculate the percentage of failures, if the fail rate > 30% write the script object into $results
$totalDeviceCount = 0
foreach ($script in $ProRemScripts) {
    $totalDeviceCount = $script.runSummary.noIssueDetectedDeviceCount + $script.runSummary.IssueDetectedDeviceCount + $script.runSummary.detectionScriptErrorDeviceCount 

    ## check for active assignments, if none the script is not in use and doesnt need to be evaluated
    if ($script.assignments.Count -eq 0) {
        Write-Host "## No assignments for Script '$($script.displayName)' found. Skipping..."
        continue
    }
    ## otherwise check the failure rate and if > 30% save the script object in $results
    elseif (($script.runSummary.issueReoccurredDeviceCount) -gt $totalDeviceCount * 0.3) {
        
        Write-Host "## Script '$($script.displayName)' added to list."
        $results += $script
    }
}


## Build an email to be sent to support and then send it
if ($sendEmailIfFound -and ($results.Count -gt 0)) {
    $tenant = Invoke-RjRbRestMethodGraph -Resource "/organization"
    $tenantName = ($tenant.verifiedDomains | Where-Object { $_.isInitial }).name

    $HTMLBody = @"
    Hello Team,<br>
    <br>
    please find below a list of Remediation Scripts that keep failing at the remediation step. Review and correct as necessary.<br>
    <br>
    <b>Tenant:</b> <br>
    $tenantName<br>
    <br>
    <b>Proactive Remediation Packages:</b><br>
    <table>
        $(foreach ($failingScript in $results) {
            "<tr><td><b>Script Name:</b> $($failingScript.displayName)</td></tr>"
            "<tr><td><b>ID:</b> $($failingScript.id)</td></tr>"
            "<tr></tr>"
        })
    </table>   
    <br>
    This is an automated eMail. Please do not reply to this eMail.<br>
"@

    $message = @{
        subject = "[Automated eMail] ALERT - Failing Proactive Remediation Scripts"
        body    = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
    }
    
    $message.toRecipients = [array]@{
        emailAddress = @{
            address = $To
        }
    }

    Invoke-RjRbRestMethodGraph -Resource "/users/$From/sendMail" -Method POST -Body @{ message = $message }
    Write-Host "## Alert sent to '$To'."
}