<#
    .SYNOPSIS
    Enable, disable or check the archive mailbox of this user

    .DESCRIPTION
    Enables or disables the in-place archive mailbox of this user, or shows its current status. Nothing changes when the mailbox is already in the requested state. When enabling, an archive that was disabled within the last 30 days is reconnected instead of creating a new one.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER Action
    Whether the archive is enabled, disabled or only its status shown. Set by the "Action" choice.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Action": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Action",
                "Select": {
                    "Options": [
                        {
                            "Display": "Enable archive mailbox",
                            "Customization": {
                                "Default": {
                                    "Action": "Enable"
                                }
                            }
                        },
                        {
                            "Display": "Disable archive mailbox",
                            "Customization": {
                                "Default": {
                                    "Action": "Disable"
                                }
                            }
                        },
                        {
                            "Display": "Get current status",
                            "Customization": {
                                "Default": {
                                    "Action": "GetStatus"
                                }
                            }
                        }
                    ]
                },
                "Default": "Get current status"
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" -Attribute 'userPrincipalName' } )]
    [String] $UserName,
    [Parameter(Mandatory = $false)]
    [ValidateSet("Enable", "Disable", "GetStatus")]
    [string] $Action = "GetStatus",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "Action: $Action" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

Connect-RjRbExchangeOnline

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

try {
    $mailbox = Get-Mailbox -Identity $UserName -ErrorAction Stop
}
catch {
    "## Could not find a mailbox for '$UserName'. Please verify the user principal name and try again."
    ""
    throw $_
}

"## Current Archive Status"
"## ---------------------"
"## User:             $UserName"
"## Archive status:   $(if ($mailbox.ArchiveStatus -eq 'Active') { 'Enabled' } else { 'Disabled' })"
if ($mailbox.ArchiveStatus -eq "Active") {
    "## Archive name:     $($mailbox.ArchiveName)"
    "## Archive quota:    $($mailbox.ArchiveQuota)"
}
if ($mailbox.ArchiveStatus -ne "Active" -and $mailbox.DisabledArchiveGuid -ne [System.Guid]::Empty) {
    "## Recoverable:      Yes (disconnected archive found - can be reconnected within 30 days)"
}
""

if ($Action -eq "GetStatus") {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    return
}

if ($Action -eq "Enable" -and $mailbox.ArchiveStatus -eq "Active") {
    "## The archive mailbox is already enabled for '$UserName'. No changes were made."
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    return
}

if ($Action -eq "Disable" -and $mailbox.ArchiveStatus -ne "Active") {
    "## The archive mailbox is not enabled for '$UserName'. No changes were made."
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    return
}

#endregion

########################################################
#region     Main Part
########################################################

if ($Action -eq "Disable") {
    "## Disabling archive mailbox for '$UserName'..."
    try {
        Disable-Mailbox -Identity $UserName -Archive -Confirm:$false -ErrorAction Stop | Out-Null
        ""
        "## Result"
        "## ------"
        "## The archive mailbox has been successfully disabled for '$UserName'."
        "## Note: The archive can be recovered within 30 days if needed."
    }
    catch {
        Write-Error "Failed to disable the archive mailbox for '$UserName': $_"
        throw
    }
}
else {
    # Enable-Mailbox -Archive reconnects a disconnected archive automatically if DisabledArchiveGuid is set,
    # otherwise it creates a new archive. Connect-Mailbox is not available in Exchange Online.
    $hasDisconnectedArchive = $mailbox.DisabledArchiveGuid -and $mailbox.DisabledArchiveGuid -ne [System.Guid]::Empty

    if ($hasDisconnectedArchive) {
        "## A disconnected archive was found. Reconnecting..."
    }
    else {
        "## No recoverable archive found. Creating a new archive mailbox..."
    }

    try {
        Enable-Mailbox -Identity $UserName -Archive -ErrorAction Stop | Out-Null
        ""
        "## Result"
        "## ------"
        if ($hasDisconnectedArchive) {
            "## The archive mailbox has been successfully reconnected for '$UserName'."
        }
        else {
            "## A new archive mailbox has been successfully created for '$UserName'."
        }
    }
    catch {
        Write-Error "Failed to enable the archive mailbox for '$UserName': $_"
        throw
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

#endregion
