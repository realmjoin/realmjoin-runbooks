<#
    .SYNOPSIS
    Resize an existing Windows 365 Cloud PC for a user

    .DESCRIPTION
    Resizes a Windows 365 Cloud PC by removing the current assignment and provisioning a new size using a different license group.
    WARNING: This operation deprovisions and reprovisions the Cloud PC and local data may be lost.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER currentLicWin365GroupName
    Current Windows 365 license group name used by the Cloud PC.

    .PARAMETER newLicWin365GroupName
    New Windows 365 license group name to assign for the resized Cloud PC.

    .PARAMETER sendMailWhenDoneResizing
    "Do not send an Email." (final value: $false) or "Send an Email." (final value: $true) can be selected as action to perform. If set to true, an email notification will be sent to the user when Cloud PC resizing has finished.

    .PARAMETER fromMailAddress
    Mailbox used to send the notification email.

    .PARAMETER customizeMail
    If set to true, uses a custom email body.

    .PARAMETER customMailMessage
    Custom message body used for the notification email.

    .PARAMETER cfgProvisioningGroupPrefix
    Prefix used to detect provisioning-related configuration groups.

    .PARAMETER cfgUserSettingsGroupPrefix
    Prefix used to detect user-settings-related configuration groups.

    .PARAMETER unassignRunbook
    Name of the runbook used to remove the current Windows 365 assignment.

    .PARAMETER assignRunbook
    Name of the runbook used to assign the new Windows 365 configuration.

    .PARAMETER skipGracePeriod
    If set to true, ends the old Cloud PC grace period immediately.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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
                "DisplayName": "The to-be-resized Cloud PC uses the following Windows365 license: ",
                "SelectSimple": {
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
                }
            },
            "newLicWin365GroupName": {
                "DisplayName": "Resizing to following license: ",
                "SelectSimple": {
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
                }
            },
            "sendMailWhenDoneResizing": {
                    "DisplayName": "Notify User once the Cloud PC has finished resizing?",
                    "Select": {
                        "Options": [
                            {
                                "Display": "Do not send an Email.",
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
                                "Display": "Send an Email.",
                                "ParameterValue": true
                            }
                        ]
                    }
                },
            "customizeMail": {
                "DisplayName": "Would you like to customize the mail sent to the user?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Do not customize the email.",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "customMailMessage"
                                ]
                            }
                        },
                        {
                            "Display": "Customize the email.",
                            "ParameterValue": true
                        }
                    ]
                }
            },
            "customizeMail": {
                "DisplayName": "Would you like to customize the mail sent to the user?"
            },
            "customMailMessage": {
                "DisplayName": "Custom message to be sent to the user."
            },
            "fromMailAddress": {
                "DisplayName": "(Shared) Mailbox to send mail from: "
            },
            "skipGracePeriod": {
                "DisplayName": "Remove the old Cloud PC immediately?"
            }
        }
    }

    .EXAMPLE
    "user_general_resizing-windows365": {
        "Parameters": {
            "licWin365GroupName": {
                "SelectSimple": {
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
                }
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

$Version = "1.0.0"
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
Start-AutomationRunbook -Name $assignRunbook -Parameters @{UserName = $UserName ; licWin365GroupName = $newLicWin365GroupName ; cfgProvisioningGroupName = $currentProvisioningPolicy ; cfgUserSettingsGroupName = $currentUserSettingsPolicy ; sendMailWhenProvisioned = $sendMailWhenDoneResizing; customizeMail = $customizeMail; customMailMessage = $customMailMessage; CallerName = $CallerName ; }