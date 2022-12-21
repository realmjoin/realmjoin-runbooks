<#
  .SYNOPSIS
  Assign/Provision a Windows 365 instance

  .DESCRIPTION
  Assign/Provision a Windows 365 instance for this user.

  .NOTES
  Permissions:
  MS Graph (API):
  - User.Read.All
  - GroupMember.ReadWrite.All 
  - Group.ReadWrite.All
  - User.SendMail

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
            "CallerName": {
                "Hide": true
            }
        }
    }

   .EXAMPLE
   "rjgit-user_general_assign-windows365": {
            "Parameters": {
                "cfgProvisioningGroupName": {
                    "SelectSimple": {
                        "cfg - Windows 365 - Provisioning - Win11": "cfg - Windows 365 - Provisioning - Win11",
                        "cfg - Windows 365 - Provisioning - Win10": "cfg - Windows 365 - Provisioning - Win10"
                    }
                },
                "cfgUserSettingsGroupName": {
                    "SelectSimple": {
                        "cfg - Windows 365 - User Settings - restore allowed": "cfg - Windows 365 - User Settings - restore allowed",
                        "cfg - Windows 365 - User Settings - no restore": "cfg - Windows 365 - User Settings - no restore"
                    }
                },
                "licWin365GroupName": {
                    "SelectSimple": {
                        "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                        "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
                    }
                }
            }
        }
#>

#Requires -Modules "RealmJoin.RunbookHelper"

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Provisioning Policy to use" } )]
    [string] $cfgProvisioningGroupName = "cfg - Windows 365 - Provisioning - Win11",
    [ValidateScript( { Use-RJInterface -DisplayName "User Settings Policy to use" } )]
    [string] $cfgUserSettingsGroupName = "cfg - Windows 365 - User Settings - restore allowed",
    [ValidateScript( { Use-RJInterface -DisplayName "Windows 365 license to assign" } )]
    [string] $licWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [bool] $sendMailWhenProvisioned = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "(Shared) Mailbox to send mail from" } )]
    [string] $fromMailAddress = "runbooks@contoso.com",
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Verify Provisioning configuration group
$cfgProvisioningGroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$cfgProvisioningGroupName'"
if (-not $cfgProvisioningGroupObj) {
    "## Could not find Provisioning policy group '$cfgProvisioningGroupName'."
    throw "cfgProvisioning not found"
}

# Verify User Settings configuration group
$cfgUserSettingsGroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$cfgUserSettingsGroupName'"
if (-not $cfgUserSettingsGroupObj) {
    "## Could not find User Settings policy group '$cfgUserSettingsGroupName'."
    throw "cfgUserSettings not found"
}

# Verify Windows 365 license group
$licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$licWin365GroupName'"
if (-not $licWin365GroupObj) {
    "## Could not find Windows 365 license group '$licWin365GroupName'."
    throw "licWin365 not found"
}

$result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
if ($result -and ($result.userPrincipalName -contains $UserName)) {
    "## '$UserName' already has a Win365 license of this type assigned." 
    "## Can not provision - exiting."
    exit
}

# Prepare for adding a group member
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"
$body = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
}

# Check / assign memberships of "cfg" groups.

$cfgProvisioningGroupIsAssigned = $false
$cfgUserSettingsGroupIsAssigned = $false
$licWin365GroupIsAssigned = $false

$allCfgProvisioningGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
foreach ($group in $allCfgProvisioningGroups) {
    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        "## '$UserName' already has a Win365 Provisioning Policy '$($group.displayName)' assigned. Skipping."
        $cfgProvisioningGroupIsAssigned = $true
    }
}
if (-not $cfgProvisioningGroupIsAssigned) {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$($cfgProvisioningGroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
    "## Assigned '$cfgProvisioningGroupName' to '$UserName'."
}

$allCfgUserSettingsGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
foreach ($group in $allCfgUserSettingsGroups) {
    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        "## '$UserName' already has a Win365 User Settings Policy '$($group.displayName)' assigned. Skipping."
        $cfgUserSettingsGroupIsAssigned = $true
    }
}
if (-not $cfgUserSettingsGroupIsAssigned) {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$($cfgUserSettingsGroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
    "## Assigned '$cfgUserSettingsGroupName' to '$UserName'."
}

# (Re-)Check assignment status before assigning license.

while (-not $cfgProvisioningGroupIsAssigned) {
    Start-Sleep -Seconds 15
    $allCfgProvisioningGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
    foreach ($group in $allCfgProvisioningGroups) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            #"## Win365 Provisioning Policy '$($group.displayName)' assigned to '$UserName'."
            $cfgProvisioningGroupIsAssigned = $true
        }
    }
} 

while (-not $cfgUserSettingsGroupIsAssigned) {
    Start-Sleep -Seconds 15
    $allCfgUserSettingsGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
    foreach ($group in $allCfgUserSettingsGroups) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            #"## Win365 User Settings Policy '$($group.displayName)' assigned to '$UserName'."
            $cfgUserSettingsGroupIsAssigned = $true
        }
    }
} 

# Assign license / Provision Cloud PC
Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
"## Assigned '$licWin365GroupName' to '$UserName'."
if (-not $sendMailWhenProvisioned) { 
    "## Cloud PC provisioning will start shortly."
}
else {

    while (-not $licWin365GroupIsAssigned) {
        Start-Sleep -Seconds 15
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            #"## Win365 lic group is '$($group.displayName)' assigned to '$UserName'."
            $licWin365GroupIsAssigned = $true
        }
    }

    # Search Cloud PC
    $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/assignedLicenses"
    $skuId = $assignedLicenses.skuId 
    $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
    $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }
    $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
    $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }

    "## Waiting for Cloud PC to begin provisioning."
    while (([array]$cloudPC).count -ne 1) {
        Start-Sleep -Seconds 15
        $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
        $cloudPC = $cloudPCs | Where-Object { (($_.servicePlanId -in $skuObj.servicePlans.servicePlanId) -and ($_.status -in @("notProvisioned","provisioning"))) }
        "."
    }

    "## Provisioning started. Waiting for Cloud PC to be ready."

    while ($cloudPC.status -notin @("provisioned", "failed")) {
        Start-Sleep -Seconds 60
        "."
    }
 
    if ($cloudPC.status -eq "provisioned") {
        "## Cloud PC provisioned."
        $message = @{
            subject = "[Automated eMail] Cloud PC is provisioned."
            body    = @{
                contentType = "HTML"
                content     = @"
            <p>This is an automated message, no reply is possible.</p>
            <p>Your Cloud PC is ready. Access via <a href="https://windows365.microsoft.com">windows365.microsoft.com</a></p>
"@
            }
        }

        $message.toRecipients = [array]@{
            emailAddress = @{
                address = $UserName
            }
        }

        Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
        "## Mail to '$UserName' sent."

    }
    else {
        "## Cloud PC provisioning failed."
        throw ("Cloud PC failed.")
    }

}