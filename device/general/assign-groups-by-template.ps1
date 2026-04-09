<#
	.SYNOPSIS
	Assign cloud-only groups to a device based on a template

	.DESCRIPTION
	Adds a device to one or more Entra ID groups using either group object IDs or display names. The list of groups is typically provided via runbook customization templates.

	.PARAMETER DeviceId
	ID of the target device in Microsoft Graph.

	.PARAMETER GroupsTemplate
	Template selector used by portal customization to populate the group list.

	.PARAMETER GroupsString
	Comma-separated list of group object IDs or group display names.

	.PARAMETER UseDisplaynames
	If set to true, treats values in GroupsString as group display names instead of IDs.

	.PARAMETER CallerName
	Caller name is tracked purely for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"DeviceId": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			},
			"UseDisplaynames": {
				"Hide": true
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [String]$DeviceId,
    # GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization
    [string]$GroupsTemplate,
    [Parameter(Mandatory = $true)]
    [string]$GroupsString,
    # $UseDisplaynames = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames
    [bool]$UseDisplaynames = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "GroupsString: $GroupsString" -Verbose
Write-RjRbLog -Message "UseDisplaynames: $UseDisplaynames" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity has the required permissions." -ErrorAction Continue
    throw $_
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight Checks"
Write-Output "---------------------"

if (-not $GroupsString) {
    Write-Output "## Please prepare Groups Templates before using this runbook."
    Write-Output "## See this runbook's source for an example."
    Write-Error "No GroupsString provided" -ErrorAction Continue
    throw "No GroupsString provided"
}

# $DeviceId from portal is the Azure AD Device ID (deviceId property), NOT the Entra Object ID.
# Filter to resolve the Entra Object ID needed for direct path operations.
try {
    $entraDevicesResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$DeviceId'&`$select=id,displayName,deviceId" -Method GET -ErrorAction Stop
    $entraDevice = $entraDevicesResult.value | Select-Object -First 1
    if (-not $entraDevice) {
        Write-Error "Device with Azure AD Device ID '$DeviceId' not found in Entra ID." -ErrorAction Continue
        throw "Device '$DeviceId' not found in Entra ID"
    }
}
catch {
    Write-Error "Failed to retrieve device from Entra ID: $_" -ErrorAction Continue
    throw $_
}

Write-Output "## Device found: $($entraDevice.displayName)"

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# Get current group memberships for the device
try {
    $currentMemberships = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices/$($entraDevice.id)/memberOf?`$select=id,displayName" -Method GET -ErrorAction Stop
    $currentGroups = @()
    if ($currentMemberships.value) {
        $currentGroups = $currentMemberships.value
    }

    if ($currentGroups.Count -gt 0) {
        Write-Output "## Current group memberships:"
        foreach ($group in $currentGroups) {
            Write-Output "   - $($group.displayName)"
        }
    }
    else {
        Write-Output "## Device is not a member of any groups"
    }
}
catch {
    Write-Error "Failed to retrieve current group memberships: $_" -ErrorAction Continue
    throw $_
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Processing Groups"
Write-Output "---------------------"

$GroupNames = $GroupsString.Split(',')

$AADGroups = @()
if ($UseDisplaynames) {
    foreach ($GroupName in $GroupNames) {
        $GroupName = $GroupName.Trim()
        try {
            $targetGroupResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$GroupName'&`$select=id,displayName" -Method GET -ErrorAction Stop
            $targetGroup = $targetGroupResult.value | Select-Object -First 1

            if (-not $targetGroup) {
                Write-Output "## Group with name '$GroupName' not found in Azure AD."
                Write-Error "Group '$GroupName' not found" -ErrorAction Continue
                throw "Group not found"
            }
            if ($targetGroupResult.value.Count -gt 1) {
                Write-Output "## Multiple groups with name '$GroupName' found in Azure AD."
                Write-Output "## Recommendation: Use Group object IDs instead of display names."
                Write-Error "Group '$GroupName' not unique" -ErrorAction Continue
                throw "Group not unique"
            }
            if ($AADGroups.id -notcontains $targetGroup.id) {
                $AADGroups += $targetGroup
            }
        }
        catch {
            Write-Error "Failed to retrieve group '$GroupName': $_" -ErrorAction Continue
            throw $_
        }
    }
}
else {
    foreach ($GroupId in $GroupNames) {
        $GroupId = $GroupId.Trim()
        try {
            $targetGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId" -Method GET -ErrorAction SilentlyContinue
            if (-not $targetGroup) {
                Write-Output "## Group with ID '$GroupId' not found in Azure AD."
                Write-Error "Group '$GroupId' not found" -ErrorAction Continue
                throw "Group not found"
            }
            if ($AADGroups.id -notcontains $targetGroup.id) {
                $AADGroups += $targetGroup
            }
        }
        catch {
            Write-Error "Failed to retrieve group '$GroupId': $_" -ErrorAction Continue
            throw $_
        }
    }
}

Write-Output ""
Write-Output "Adding Device to Groups"
Write-Output "---------------------"

foreach ($AADGroup in $AADGroups) {
    try {
        # Get current group members
        $AADGroupMembersResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($AADGroup.id)/members?`$select=id" -Method GET -ErrorAction Stop
        $AADGroupMembers = @()
        if ($AADGroupMembersResult.value) {
            $AADGroupMembers = $AADGroupMembersResult.value.id
        }

        [array]$bindings = @()

        # Check if device is already a member
        if ((-not $AADGroupMembers) -or ($AADGroupMembers -notcontains $entraDevice.id)) {
            $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$($entraDevice.id)"
            $bindings += $bindingString
        }
        else {
            Write-Output "## Device is already member of '$($AADGroup.displayName)'. Skipping."
        }

        if ($bindings) {
            $GroupJson = @{"members@odata.bind" = $bindings }
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($AADGroup.id)" -Method PATCH -Body $GroupJson -ErrorAction Stop | Out-Null
            Write-Output "## Added device to group '$($AADGroup.displayName)'"
        }
    }
    catch {
        Write-Error "Failed to add device to group '$($AADGroup.displayName)': $_" -ErrorAction Continue
        throw $_
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
