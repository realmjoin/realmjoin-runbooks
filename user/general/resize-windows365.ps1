<#
 .SYNOPSIS
 Resize a Windows 365 Cloud PC

 .DESCRIPTION
 Resize an already existing Windows 365 Cloud PC by derpovisioning and assigning a new differently sized license to the user. Warning: All local data will be lost. Proceed with caution.

 .NOTES
 Permissions:
 MS Graph (API):
 - GroupMember.ReadWrite.All 
 - Group.ReadWrite.All
 - Directory.Read.All
 - CloudPC.ReadWrite.All (Beta)
 - User.Read.All
 - User.SendMail

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
        "SelectSimple": {
            "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
            "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
        }
    },
    "newLicWin365GroupName": {
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
                                "fromMailAddress"
                            ]
                        }
                    },
                    {
                        "Display": "Send an Email.",
                        "ParameterValue": true
                    }
                ]
            }
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJRbInterface -Type Graph -Entity User -DisplayName "User" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "The to-be-resized Cloud PC uses the following Windows365 license: " } )]
    [Parameter(Mandatory = $true)]
    [string] $currentLicWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [ValidateScript( { Use-RJInterface -DisplayName "Resizing to following license: " } )]
    [Parameter(Mandatory = $true)]
    [string] $newLicWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB",
    [ValidateScript( { Use-RJInterface -DisplayName "Notify User once the Cloud PC has finished resizing?" } )]
    [bool] $sendMailWhenDoneResizing = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "(Shared) Mailbox to send mail from: " } )]
    [string] $fromMailAddress = "reports@contoso.com",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [string] $unassignRunbook = "rjgit-user_general_unassign-windows365",
    [string] $assignRunbook = "rjgit-user_general_assign-windows365",
    [ValidateScript( { Use-RJInterface -DisplayName "Remove the old Cloud PC immediately?" } )]
    [bool] $skipGracePeriod = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Logging Caller
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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
    if (([array]$assignedLicenses).count -eq 1) {
        $skuId = $assignedLicenses.skuId 
        $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
        $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }
        $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
        $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }
    }
    elseif ($assignedLicenses.count -gt 1) {
        "## More than one license assigned to '$currentLicWin365GroupName'."
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
Start-AutomationRunbook -Name $assignRunbook -Parameters @{UserName = $UserName ; licWin365GroupName = $newLicWin365GroupName ; cfgProvisioningGroupName = $currentProvisioningPolicy ; cfgUserSettingsGroupName = $currentUserSettingsPolicy ; sendMailWhenProvisioned = $sendMailWhenDoneResizing; CallerName = $CallerName ; }