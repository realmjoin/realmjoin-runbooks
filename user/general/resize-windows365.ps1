<#
    .SYNOPSIS
    Resize the Windows 365 Cloud PC of this user

    .DESCRIPTION
    Moves the Windows 365 Cloud PC of this user to a different size by removing the current license assignment and provisioning a new Cloud PC with the new license. The old Cloud PC is deprovisioned, so data stored only on it is lost; ask the user to back up first. Optionally the user gets an email when the new Cloud PC is ready.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER currentLicWin365GroupName
    License group the user is removed from; the Cloud PC behind it is deprovisioned.

    .PARAMETER newLicWin365GroupName
    License group that provides the new size. Must differ from the current one.

    .PARAMETER sendMailWhenDoneResizing
    Sends the user an email once the new Cloud PC is ready.

    .PARAMETER fromMailAddress
    Mailbox the notification email is sent from.

    .PARAMETER customizeMail
    Replaces the standard notification text with your own message.

    .PARAMETER customMailMessage
    Text of the notification email.

    .PARAMETER cfgProvisioningGroupPrefix
    Name prefix that identifies provisioning policy groups. Preset in the runbook customization.

    .PARAMETER cfgUserSettingsGroupPrefix
    Name prefix that identifies user settings policy groups. Preset in the runbook customization.

    .PARAMETER unassignRunbook
    Name of the runbook that removes the current assignment. Preset in the runbook customization.

    .PARAMETER assignRunbook
    Name of the runbook that assigns the new size. Preset in the runbook customization.

    .PARAMETER skipGracePeriod
    Deletes the old Cloud PC right away instead of after the 7-day grace period.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "unassignRunbook": {
                "Hide": true
            },
            "assignRunbook": {
                "Hide": true
            },
            "cfgProvisioningGroupPrefix": {
                "Hide": true
            },
            "cfgUserSettingsGroupPrefix": {
                "Hide": true
            },
            "currentLicWin365GroupName": {
                "DisplayName": "Current Windows 365 license"
            },
            "newLicWin365GroupName": {
                "DisplayName": "New Windows 365 license"
            },
            "sendMailWhenDoneResizing": {
                "DisplayName": "Notify the user when the resize is done?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "fromMailAddress",
                                    "customizeMail",
                                    "customMailMessage"
                                ]
                            }
                        },
                        {
                            "Display": "Send an email",
                            "ParameterValue": true
                        }
                    ]
                }
            },
            "customizeMail": {
                "DisplayName": "Customize the notification email?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Use the standard email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "customMailMessage"
                                ]
                            }
                        },
                        {
                            "Display": "Use a custom message",
                            "ParameterValue": true
                        }
                    ]
                }
            },
            "customMailMessage": {
                "DisplayName": "Custom message"
            },
            "fromMailAddress": {
                "DisplayName": "Sender mailbox"
            },
            "skipGracePeriod": {
                "DisplayName": "Remove the old Cloud PC immediately?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $currentLicWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [Parameter(Mandatory = $true)]
    [string] $newLicWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB",
    [bool] $sendMailWhenDoneResizing = $false,
    [string] $fromMailAddress = "reports@contoso.com",
    [bool] $customizeMail = $false,
    [string] $customMailMessage = "Insert Custom Message here. (Capped at 3000 characters)",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [string] $unassignRunbook = "rjgit-user_general_unassign-windows365",
    [string] $assignRunbook = "rjgit-user_general_assign-windows365",
    [bool] $skipGracePeriod = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Logging Caller
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# User exists?
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# User wants to resize to the same size? Denied.
if ($currentLicWin365GroupName -eq $newLicWin365GroupName) {
    "## Same size as the current one has been selected: '$newLicWin365GroupName'. Will not proceed. Choose a different size."
    throw "new licWin365 equals current one"
}

# Verify Windows 365 license group
$currentLicWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$currentLicWin365GroupName'"
if (-not $currentLicWin365GroupObj) {
    "## Could not find Windows 365 license group '$currentLicWin365GroupName'."
    throw "licWin365 not found"
}

# Check the to-be-resized CPC exists
$result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($currentLicWin365GroupObj.id)/members"
if ($result -and ($result.userPrincipalName -contains $UserName)) {
    # Find Cloud PC via SKU
    $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($currentLicWin365GroupObj.id)/assignedLicenses"
    if (([array]$assignedLicenses).count -gt 1) {
        "## Warning: More than one license assigned to '$currentLicWin365GroupName'."
    }
}
else {
    "## '$UserName' does not have '$currentLicWin365GroupName'."
    "## Can not resize."
    throw "Cloud PC with license '$currentLicWin365GroupName' does not exist."
}

# Verify new Windows 365 license group has an available/unassigned license for the user
# Grab the to-be-assigned License group
$newLicWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$newLicWin365GroupName'"

# Get License / SKU data
$assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($newLicWin365GroupObj.id)/assignedLicenses"
$skuId = $assignedLicenses.skuId
$SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus"
$skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }

# Are licenses available?
if ($skuObj.prepaidUnits.enabled -le $skuObj.consumedUnits) {
    "## Not enough licenses avaible to assign '$newLicWin365GroupName'. Consider stocking up on this particular license."
    throw "No available free licenses in '$newLicWin365GroupName'."
}

# Fetch the currently used configuration policies
$currentUserSettingsPolicy = $null
$allCfgUserSettingsGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
foreach ($group in $allCfgUserSettingsGroups) {
    if (-not $currentUserSettingsPolicy) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            $currentUserSettingsPolicy = $group.displayName
            "## '$UserName' has the following Setting Group: '$currentUserSettingsPolicy'."
        }
    }
}
if (-not $currentUserSettingsPolicy) {
    "## Warning: '$UserName' has no Setting Group assigned."
}

$allCfgProvisioningGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
$currentProvisioningPolicy = $null
foreach ($group in $allCfgProvisioningGroups) {
    if (-not $currentProvisioningPolicy) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            $currentProvisioningPolicy = $group.displayName
            "## '$UserName' has the following Provisioning Group: '$currentProvisioningPolicy'."
        }
    }
}
if (-not $currentProvisioningPolicy) {
    "## Warning: '$UserName' has no Provisioning Group assigned."
}

# Calling Runbooks
"## Starting Runbook Job to remove '$currentLicWin365GroupName' from '$UserName':"
Start-AutomationRunbook -Name $unassignRunbook -Parameters @{UserName = $UserName ; licWin365GroupName = $currentLicWin365GroupName ; skipGracePeriod = $skipGracePeriod ; keepUserSettingsAndProvisioningGroups = $true; CallerName = $CallerName ; }
""
"## Starting Runbook Job to assign '$newLicWin365GroupName' to '$UserName':"
Start-AutomationRunbook -Name $assignRunbook -Parameters @{UserName = $UserName ; licWin365GroupName = $newLicWin365GroupName ; cfgProvisioningGroupName = $currentProvisioningPolicy ; cfgUserSettingsGroupName = $currentUserSettingsPolicy ; sendMailWhenProvisioned = $sendMailWhenDoneResizing; fromMailAddress = $fromMailAddress ; customizeMail = $customizeMail; customMailMessage = $customMailMessage; CallerName = $CallerName ; }