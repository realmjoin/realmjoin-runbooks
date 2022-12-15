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
    #$licWin365GroupIsAssigned = $true
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
    "## Assigned '$cfgProvisioningGroupName' to '$UserName'"
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
    "## Assigned '$cfgUserSettingsGroupName' to '$UserName'"
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
            "## Win365 User Settings Policy '$($group.displayName)' assigned to '$UserName'."
            $cfgUserSettingsGroupIsAssigned = $true
        }
    }
} 

# Assign license / Provision Cloud PC
Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
"## Win365 License '$licWin365GroupName' assigned. Cloud PC provisioning will start shortly."

