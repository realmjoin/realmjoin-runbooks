<#
    .SYNOPSIS
    Register a Windows device in Windows Autopilot

    .DESCRIPTION
    Registers a Windows device in Windows Autopilot from its serial number and hardware hash, as collected with Get-WindowsAutopilotInfo. Optionally a group tag is set during the import and the runbook waits until the import has finished.

    .PARAMETER SerialNumber
    Serial number of the device as reported by Get-WindowsAutopilotInfo.

    .PARAMETER HardwareIdentifier
    Hardware hash of the device as reported by Get-WindowsAutopilotInfo.

    .PARAMETER AssignedUser
    User to assign during the import. Microsoft no longer accepts this, so leave it empty.

    .PARAMETER Wait
    Keeps the runbook running until Autopilot has processed the import, so the result shows in the output.

    .PARAMETER GroupTag
    Group tag to set on the device, for example to steer it into an Autopilot profile. Leave empty for none.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SerialNumber": {
                "DisplayName": "Serial number"
            },
            "HardwareIdentifier": {
                "DisplayName": "Hardware hash"
            },
            "AssignedUser": {
                "DisplayName": "Assign device to this user (optional)",
                "Hide": true
            },
            "Wait": {
                "DisplayName": "Wait for the import to finish?"
            },
            "GroupTag": {
                "DisplayName": "Group tag"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$body = @{
    serialNumber       = $SerialNumber
    hardwareIdentifier = $HardwareIdentifier
    # groupTag = ""
}

## MS removed the ability to assign users directly via Autopilot
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
