<#
	.SYNOPSIS
	List the devices registered to this group's members

	.DESCRIPTION
	Lists the devices registered to the users in this group. Optionally the found devices are added to a device group of your choice. Devices are only added to that group, never removed.

	.PARAMETER GroupID
	Object ID of the group the runbook acts on. Set by the portal from the selected group.

	.PARAMETER moveGroup
	Whether the found devices are added to the chosen device group. Set by the "Action" choice.

	.PARAMETER targetgroup
	Group the found devices are added to. Only used when "Action" adds the devices.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"moveGroup": {
				"Hide": true
			},
			"GroupID": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Action",
				"DisplayBefore": "targetgroup",
				"Select": {
					"Options": [
						{
							"Display": "Add the members' devices to a device group",
							"ParameterValue": "Add the members' devices to a device group",
							"Customization": {
								"Default": {
									"moveGroup": true
								}
							}
						},
						{
							"Display": "List the members' devices only",
							"ParameterValue": "List the members' devices only",
							"Customization": {
								"Default": {
									"moveGroup": false
								},
								"Hide": [
									"targetgroup"
								]
							}
						}
					]
				},
				"Default": "Add the members' devices to a device group"
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [bool]$moveGroup = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Device group" } )]
    [String] $targetgroup,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "GroupID: $GroupID" -Verbose
Write-RjRbLog -Message "moveGroup: $moveGroup" -Verbose
Write-RjRbLog -Message "targetgroup: $targetgroup" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ([string]::IsNullOrWhiteSpace($GroupID)) {
    Write-Error "GroupID is empty. Select a group to list the devices of its members." -ErrorAction Continue
    throw "GroupID is empty"
}

if ($moveGroup -and [string]::IsNullOrWhiteSpace($targetgroup)) {
    Write-Error "No device group selected. Choose a group to add the devices to, or switch the action to list only." -ErrorAction Continue
    throw "targetgroup is empty"
}

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

$group = $null
try {
    $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($GroupID))?`$select=id,displayName" -Method GET -ErrorAction Stop
}
catch { }
if (-not $group) {
    Write-Error "Group '$GroupID' not found." -ErrorAction Continue
    throw "Group not found"
}

$targetGroupObject = $null
$targetGroupMemberIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($moveGroup) {
    try {
        $targetGroupObject = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($targetgroup))?`$select=id,displayName" -Method GET -ErrorAction Stop
    }
    catch { }
    if (-not $targetGroupObject) {
        Write-Error "Device group '$targetgroup' not found." -ErrorAction Continue
        throw "Device group not found"
    }
    try {
        foreach ($existingMember in @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($targetgroup))/members?`$select=id")) {
            [void]$targetGroupMemberIds.Add([string]$existingMember.id)
        }
    }
    catch {
        Write-Error "Failed to read the members of device group '$($targetGroupObject.displayName)': $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
    Write-Output "Target device group: '$($targetGroupObject.displayName)' ($($targetGroupMemberIds.Count) current member(s))"
}

Write-Output "Source group: '$($group.displayName)'"
Write-Output "Collecting the registered devices of the group members. This may take some time for large groups."

$deviceRows = [System.Collections.Generic.List[object]]::new()
$unreadableRows = [System.Collections.Generic.List[object]]::new()
$skippedNonUsers = 0

try {
    $groupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($GroupID))/members")
}
catch {
    Write-Error "Failed to read the members of group '$($group.displayName)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}

$membersWithDevices = 0
foreach ($groupMember in $groupMembers) {
    if ($groupMember.'@odata.type' -and $groupMember.'@odata.type' -ne '#microsoft.graph.user') {
        $skippedNonUsers++
        continue
    }
    $memberName = if ($groupMember.userPrincipalName) { $groupMember.userPrincipalName } else { $groupMember.displayName }
    try {
        $userDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString([string]$groupMember.id))/registeredDevices")
    }
    catch {
        $unreadableRows.Add([PSCustomObject]@{ Member = $memberName; Reason = $_.Exception.Message })
        continue
    }
    if ($userDevices.Count -gt 0) { $membersWithDevices++ }
    foreach ($userDevice in $userDevices) {
        $deviceRows.Add([PSCustomObject]@{
                Member          = $memberName
                DeviceName      = $userDevice.displayName
                DeviceId        = $userDevice.deviceId
                OperatingSystem = $userDevice.operatingSystem
                ObjectId        = $userDevice.id
            })
    }
}

Write-Output "Group members: $($groupMembers.Count) (non-user members skipped: $skippedNonUsers)"
Write-Output "Members with registered devices: $membersWithDevices"
Write-Output "Registered devices found: $($deviceRows.Count)"
if ($unreadableRows.Count -gt 0) {
    Write-Output "Members whose devices could not be read: $($unreadableRows.Count)"
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

$addedCount = 0
$alreadyInGroupCount = 0

if ($moveGroup) {
    Write-Output ""
    Write-Output "Add devices to group"
    Write-Output "---------------------"

    $newDeviceIds = @($deviceRows | Where-Object { $_.ObjectId } | ForEach-Object { [string]$_.ObjectId } | Select-Object -Unique)
    $toAdd = @($newDeviceIds | Where-Object { -not $targetGroupMemberIds.Contains($_) })
    $alreadyInGroupCount = $newDeviceIds.Count - $toAdd.Count

    if ($toAdd.Count -eq 0) {
        Write-Output "No devices to add to group '$($targetGroupObject.displayName)'."
    }
    else {
        # Graph accepts at most 20 members per request
        try {
            for ($i = 0; $i -lt $toAdd.Count; $i += 20) {
                $chunk = @($toAdd[$i..([Math]::Min($i + 19, $toAdd.Count - 1))])
                $bindings = @($chunk | ForEach-Object { "https://graph.microsoft.com/v1.0/directoryObjects/$_" })
                $body = @{ "members@odata.bind" = $bindings } | ConvertTo-Json -Depth 3
                Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($targetgroup))" -Method PATCH -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
                $addedCount += $chunk.Count
            }
        }
        catch {
            Write-Error "Failed to add devices to group '$($targetGroupObject.displayName)' ($addedCount added before the error): $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
        Write-Output "Added $addedCount device(s) to group '$($targetGroupObject.displayName)' ($alreadyInGroupCount already members)."
    }
}

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker and column set; a marker is only
# written when rows follow it, an empty category gets a status line instead.
Write-Output ""

$summaryValues = [ordered]@{
    "Group members"                  = $groupMembers.Count
    "Members with registered devices" = $membersWithDevices
    "Registered devices"             = $deviceRows.Count
}
if ($moveGroup) {
    $summaryValues["Devices added to group"] = $addedCount
    $summaryValues["Devices already in group"] = $alreadyInGroupCount
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($deviceRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Registered devices" })
    Write-Output @($deviceRows | Sort-Object -Property Member, DeviceName | Select-Object -Property Member, DeviceName, DeviceId, OperatingSystem)
}
else {
    Write-Output "No devices found (or no access)."
}

if ($unreadableRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Members not readable" })
    Write-Output @($unreadableRows | Select-Object -Property Member, Reason)
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
