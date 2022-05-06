<#
  .SYNOPSIS
  List all devices owned by group members.

  .DESCRIPTION
  List all devices owned by group members.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.Read.All

  .INPUTS
  RunbookCustomization: {
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "targetgroup",
                "Select": {
                    "Options": [
                        {
                            "Display": "put devices owned by group members in specified AAD Group",
                            "Customization": {
                                "Default": {
                                    "moveGroup": true
                                }
                            }
                        }, {
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
                "Default": "put devices owned by group members in specified AAD Group"
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
            },
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Usergroup" } )]
    [String] $GroupID,
    [ValidateScript( { Use-RJInterface -DisplayName "List Devices owned by Group Members" } )]
    [bool]$moveGroup = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Devicegroup" } )]
    [String] $targetgroup,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)
Connect-RjRbGraph
$devicelist = New-Object System.Collections.ArrayList
try {
    $GroupMembers = Invoke-RjRbRestMethodGraph -Resource "/Groups/$($GroupID)/Members"
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
            Invoke-RjRbRestMethodGraph -Resource "/groups/$targetgroup" -Method "Patch" -Body $deviceGroupbody
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