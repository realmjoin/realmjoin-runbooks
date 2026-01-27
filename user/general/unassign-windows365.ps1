<#
  .SYNOPSIS
  Remove/Deprovision a Windows 365 instance

  .DESCRIPTION
  Remove/Deprovision a Windows 365 instance

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "cfgProvisioningGroupPrefix": {
                "Hide": true
            },
            "cfgUserSettingsGroupPrefix": {
                "Hide": true
            },
            "licWin365GroupPrefix": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "licWin365GroupName": {
                "DisplayName": "Windows 365 license/Frontline prov. policy to remove from"
            },
            "skipGracePeriod": {
                "DisplayName": "Remove Cloud PC immediately"
            }
        }
    }

   .EXAMPLE
   "rjgit-user_general_unassign-windows365": {
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
    [String] $UserName,
    [string] $licWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [string] $licWin365GroupPrefix = "lic - Windows 365 Enterprise - ",
    [bool] $skipGracePeriod = $true,
    [bool] $KeepUserSettingsAndProvisioningGroups = $false,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph


# Find the user object
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"

# Check if licWin365GroupName actually is a provisioning policy for FrontLine workers
$cfgProvisioningPolObj = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/provisioningPolicies" -OdFilter "displayName eq '$licWin365GroupName'" -UriQueryRaw '$expand=assignments' -Beta

# FrontLine workers / shared mode
if ($cfgProvisioningPolObj -and ($cfgProvisioningPolObj[0].provisioningType -eq "shared")) {
    "## Provisioning policy '$($cfgProvisioningPolObj.displayName)' uses provisioning type 'shared' (FrontLine Worker)."
    # Get the shared use service plan and assignment group from the assignments object of the policy
    $cfgProvisioningGroupId = $null
    # This will use the FIRST valid assignment - not usable for multiple sizes in one Prov. Policy
    ForEach ($assignment in $cfgProvisioningPolObj.assignments) {
        if ($assignment.target.groupId) {
            "## Found Assignment Group for Provisioning policy '$($cfgProvisioningPolObj.displayName)'."
            $cfgProvisioningGroupId = $assignment.target.groupId
            #$cfgProvisioningSharedUseServicePlanId = $assignment.target.servicePlanId
            break
        }
    }
    if (-not $cfgProvisioningGroupId) {
        "## Could not find Assignment Group for Provisioning policy '$($cfgProvisioningPolObj.displayName)'."
        throw "cfgProvisioningSharedInfo not found"
    }

    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$cfgProvisioningGroupId/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$cfgProvisioningGroupId/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
        "## Unassgined '$($cfgProvisioningPolObj.displayName)' from '$UserName'."
    }

    if ($skipGracePeriod) {
        "## Skip grace period of Cloud PC"
        $cloudPCs = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -OdFilter "userPrincipalName eq '$UserName'" -Beta
        $cloudPC = $cloudPCs | Where-Object { $_.provisioningPolicyId -eq $cfgProvisioningPolObj.id }
        if (([array]$cloudPC).count -eq 1) {
            "## CloudPC found. Waiting for it to enter grace period."
            # status -in notProvisioned, provisioning, provisioned, upgrading, inGracePeriod, deprovisioning, failed, restoring
            while ($cloudPC.status -in @("provisioned", "notProvisioned", "failed")) {
                Start-Sleep -Seconds 30
                "## ."
                $cloudPC = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$($cloudPC.id)" -Beta -ErrorAction SilentlyContinue
            }
            if ($cloudPC.status -eq "inGracePeriod") {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$($cloudPC.id)/endGracePeriod" -Method Post -Beta
                "## CloudPC grace period ended."
            }
            elseif ($cloudPC) {
                "## CloudPC in state '$($cloudPC.status)'. Please check manually."
            }
        }
    }
}
else {
    # "Dedicated" Win365 mode
    # Verify Windows 365 license group
    $licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$licWin365GroupName'"
    if (-not $licWin365GroupObj) {
        "## Could not find Windows 365 license group '$licWin365GroupName'."
        throw "licWin365 not found"
    }

    # Make sure the Win365 license is unassigned.
    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        # Find Cloud PC via SKU
        $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/assignedLicenses"
        if (([array]$assignedLicenses).count -eq 1) {
            $skuId = $assignedLicenses.skuId
            $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus"
            $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }
            $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
            $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }
        }
        elseif ($assignedLicenses.count -gt 1) {
            "## More than one license assigned to '$licWin365GroupName'"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
        "## Unassgined '$licWin365GroupName' from '$UserName'."

        if ($skipGracePeriod) {
            "## Skip grace period of Cloud PC"
            if (([array]$cloudPC).count -eq 1) {
                "## CloudPC found. Waiting for it to enter grace period."
                # status -in notProvisioned, provisioning, provisioned, upgrading, inGracePeriod, deprovisioning, failed, restoring
                while ($cloudPC.status -in @("provisioned", "notProvisioned", "failed")) {
                    Start-Sleep -Seconds 30
                    "## ."
                    $cloudPC = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$($cloudPC.id)" -Beta -ErrorAction SilentlyContinue
                }
                if ($cloudPC.status -eq "inGracePeriod") {
                    Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$($cloudPC.id)/endGracePeriod" -Method Post -Beta
                    "## CloudPC grace period ended."
                }
                elseif ($cloudPC) {
                    "## CloudPC in state '$($cloudPC.status)'. Please check manually."
                }
            }
        }
    }
    else {
        "## '$UserName' does not have '$licWin365GroupName'."
        "## Can not deprovision."
    }
}

if (-not $keepUserSettingsAndProvisioningGroups) {
    # Are any other Cloud PCs assigned to this user? - Dedicated
    $licWin365GroupIsAssigned = $false
    $allLicWin365Groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$licWin365GroupPrefix')"
    foreach ($group in $allLicWin365Groups) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            $licWin365GroupIsAssigned = $true
            "## Other Cloud PCs are assigned to this user. Will not remove Prov. or User Settings policies."
        }
    }
    # Are any other Frontline Worker Cloud PCs assigned to this user? (Shared)
    $licWin365GroupIsAssigned = $false
    $allProvPolicies = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/provisioningPolicies" -UriQueryRaw '$expand=assignments' -Beta
    $allProvPolicies = $allProvPolicies | Where-Object { $_.provisioningType -eq "shared" }
    foreach ($policy in $allProvPolicies) {
        foreach ($assignment in $policy.assignments) {
            if ((-not $licWin365GroupIsAssigned) -and $assignment.target.groupId) {
                $groupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$($assignment.target.groupId)/members"
                if ($groupMembers -and ($groupMembers.userPrincipalName -contains $UserName)) {
                    $licWin365GroupIsAssigned = $true
                }
            }
        }
        if ($licWin365GroupIsAssigned) {
            "## Other Cloud PCs are assigned to this user. Will not remove Prov. or User Settings policies."
            break
        }
    }
    if (-not $licWin365GroupIsAssigned) {
        "## No other Cloud PCs exists for '$UserName'."
        "## Removing Provisinging Policy and User Settings."

        [array]$groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
        $groups += Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
        foreach ($group in $groups) {
            $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
            if ($result -and ($result.userPrincipalName -contains $UserName)) {
                "## Removing '$($group.displayName)' from '$UserName'."
                Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
            }
        }
    }
}
else {
    "## Keeping Provisinging Policy and User Settings."
}
