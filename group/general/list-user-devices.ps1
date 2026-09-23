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
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "targetgroup",
                "Select": {
                    "Options": [
                        {
                            "Display": "Add the members' devices to a device group",
                            "Customization": {
                                "Default": {
                                    "moveGroup": true
                                }
                            }
                        },
                        {
                            "Display": "List the members' devices only",
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
            },
            {
                "Name": "CallerName",
                "Hide": true
            },
            {
                "Name": "moveGroup",
                "Hide": true
            },
            {
                "Name": "GroupID",
                "Hide": true
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [bool]$moveGroup = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Device group" } )]
    [String] $targetgroup,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$devicelist = New-Object System.Collections.ArrayList
try {
    $GroupMembers = Invoke-RjRbRestMethodGraph -Resource "/Groups/$($GroupID)/Members" -FollowPaging
    foreach ($GroupMember in $GroupMembers) {

        try {
            $UserDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$($GroupMember.id)/registeredDevices"
            if ($UserDevices) {
                $devicelist += $UserDevices
            }
        }
        catch {
            $_
        }

    }
}
catch {
    $_
}

if ($devicelist.Count -gt 0) {
    $devicelist | Format-Table -AutoSize -Property "deviceid", "DisplayName" | Out-String
    if ($moveGroup) {
        $deviceIds = New-Object System.Collections.ArrayList($null)
        foreach ($device in $devicelist) {
            [void]$deviceIds.Add($device.Id)
        }
        $bindings = @()
        foreach ($deviceId in $deviceIds) {
            $bindings += "https://graph.microsoft.com/v1.0/directoryObjects/" + $deviceId.ToString()
        }
        $deviceGroupbody = @{"members@odata.bind" = $bindings }
        try {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$targetgroup" -Method "Patch" -Body $deviceGroupbody | out-null
            "## moved devices to group with ID: $targetgroup"
        }
        catch {
            $_
        }
    }

}
else {
    "## No devices found (or no access)."
}