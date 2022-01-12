<#
  .SYNOPSIS
  Import a windows device into Windows Autopilot.

  .DESCRIPTION
  Import a windows device into Windows Autopilot.

  .NOTES
  Permissions: 
  MS Graph (API):
  - DeviceManagementServiceConfig.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "SerialNumber": {
                "DisplayName": "'Device Serial Number' from Get-WindowsAutopilotInfo"   
            },
            "HardwareIdentifier": {
                "DisplayName": "'Hardware Hash' from Get-WindowsAutopilotInfo"
            },
            "AssignedUser": {
                "DisplayName": "Assign device to this user (optional)"
            },
            "Wait": {
                "DisplayName": "Wait for job to finish"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "'Device Serial Number' from Get-WindowsAutopilotInfo" } )]
    [string] $SerialNumber,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "'Hardware Hash' from Get-WindowsAutopilotInfo" } )]
    [string] $HardwareIdentifier,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Assign device to this user (optional)"  -Filter "userType eq 'Member'" } )]
    [string] $AssignedUser = "",
    [ValidateScript( { Use-RJInterface -DisplayName "Wait for job to finish" } )]
    [bool] $Wait = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Connect-RjRbGraph

$body = @{
    serialNumber       = $SerialNumber 
    hardwareIdentifier = $HardwareIdentifier
    # groupTag = ""
}

# Find assigned user's name
if ($AssignedUser) {
    $username = (Invoke-RjRbRestMethodGraph -Resource "/users/$AssignedUser").UserPrincipalName
    $body += @{ assignedUserPrincipalName = $username }
}

# Start the import
$result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities" -Method "POST" -Body $body

"## Import of device $SerialNumber started."

# Track the import's progress
if ($Wait) {
    while (($result.state.deviceImportStatus -ne "complete") -and ($result.state.deviceImportStatus -ne "error")) {
        "## ."
        Start-Sleep -Seconds 20
        $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($result.id)" -Method Get
    }
    if ($result.state.deviceImportStatus -eq "complete") {
        "## Import of device $SerialNumber is successfull."
    }
    else {
        write-error ($result.state)
        throw "Import of device $SerialNumber failed."
    }
}

