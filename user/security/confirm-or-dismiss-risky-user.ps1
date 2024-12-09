<#
  .SYNOPSIS
  Confirm compromise / Dismiss a "risky user"

  .DESCRIPTION
  Confirm compromise / Dismiss a "risky user"

  .NOTES
  Permissions needed:
  - IdentityRiskyUser.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Dismiss": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Confirm compromise": false,
                    "Dismiss risk": true
                }
            },
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Textarea -DisplayName "Dismiss risk" } )]
    [boolean] $Dismiss = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

$outputString = "## Trying to "
if ($Dismiss) {
    $outputString += "dismiss "
}
else {
    $outputString += "confirm "
} 
$outputString += "user risk for '$UserName'."
$outputString

Connect-RjRbGraph

# "Checking risk status of $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    "## '$UserName' is not in list of risky users. No action taken."
    exit
}

#"Current risk: $($targetUser.riskState)"
#if ($targetUser.riskState -eq "confirmedCompromised") {
# "User risk for $UserName already set to 'confirmed compromised'. No action taken."
# exit
#} 

$body = @{ "userIds" = ([array]$targetUser.id) }
if ($Dismiss) {
    if (($targetUser.riskState -eq "atRisk") -or ($targetUser.riskState -eq "confirmedCompromised")) {
        Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers/dismiss" -Body $body -Method Post | Out-Null
        "## User risk for '$UserName' successfully dismissed."
    }
    else {
        "## User '$UserName' not at risk. No action taken."
    }    
}
else {
    Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers/confirmCompromised" -Body $body -Method Post | Out-Null
    "## Compromise for '$UserName' successfully confirmed."    
}

