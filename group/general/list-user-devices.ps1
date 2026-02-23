<#
    .SYNOPSIS
    List devices owned by group members.

    .DESCRIPTION
    This runbook enumerates the users in a group and lists their registered devices.
    Optionally, it can add the discovered devices to a specified device group.
    Use this to create or maintain a device group based on group member ownership.

    .PARAMETER GroupID
    Object ID of the group whose members will be evaluated.

    .PARAMETER moveGroup
    If set to true, the discovered devices are added to the target device group.

    .PARAMETER targetgroup
    Object ID of the target device group that receives the devices when moveGroup is enabled.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "targetgroup",
                "Select": {
                    "Options": [
                        {
                            "Display": "Put devices owned by group members in specified AAD (device) Group",
                            "Customization": {
                                "Default": {
                                    "moveGroup": true
                                }
                            }
                        },
                        {
                            "Display": "list devices owned by group members",
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
                "Default": "Put devices owned by group members in specified AAD (device) Group"
            },
            {
                "Name": "CallerName",
                "Hide": true
            },
            {
                "Name": "moveGroup",
                "Hide": true,
                "DisplayName": "Put devices owned by group members in specified AAD (device) Group"
            },
            {
                "Name": "GroupID",
                "Hide": true
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

$Version = "1.0.0"
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