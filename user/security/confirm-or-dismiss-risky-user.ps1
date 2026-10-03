<#
    .SYNOPSIS
    Confirm this user as compromised or dismiss the risk

    .DESCRIPTION
    Tells Microsoft Entra ID Protection what to do with the risk flagged on this user. Confirm compromise marks the account as compromised, which sets the user risk to high. Dismiss risk clears the flag when the activity was legitimate.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER Dismiss
    Confirm compromise marks the account as compromised. Dismiss risk clears the risk flag.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Textarea -DisplayName "Action" } )]
    [boolean] $Dismiss = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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

