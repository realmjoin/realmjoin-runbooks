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
                "DisplayName": "Assign device to this user (optional)",
                "Hide": true // MS removed the ability to assign users directly via Autopilot
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumber,
    [Parameter(Mandatory = $true)]
    [string] $HardwareIdentifier,
    ## MS removed the ability to assign users directly via Autopilot
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Assign device to this user (optional)"  -Filter "userType eq 'Member'" } )]
    [string] $AssignedUser = "",
    [bool] $Wait = $true,
    [string] $GroupTag = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$body = @{
    serialNumber       = $SerialNumber 
    hardwareIdentifier = $HardwareIdentifier
    # groupTag = ""
}

## MS removed the abaility to assign users directly via Autopilot
if ($AssignedUser) {
    ## Find assigned user's name
    $username = (Invoke-RjRbRestMethodGraph -Resource "/users/$AssignedUser").UserPrincipalName
    $body += @{ assignedUserPrincipalName = $username }
}

if ($groupTag) {
    $body += @{ groupTag = $GroupTag }
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
