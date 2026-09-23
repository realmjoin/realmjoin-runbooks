<#
    .SYNOPSIS
    Create or remove an Exchange Online public folder

    .DESCRIPTION
    Creates a public folder in Exchange Online, optionally in a chosen public folder mailbox, or removes an existing one. At least one public folder mailbox must already exist; the runbook does not create any.

    .PARAMETER PublicFolderName
    Name of the public folder to create or remove.

    .PARAMETER MailboxName
    Public folder mailbox the new folder is created in. Leave empty to let Exchange choose.

    .PARAMETER AddPublicFolder
    Whether the folder is created or removed. Set by the action selected in the portal.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "MailboxName",
                "Select": {
                    "Options": [
                        {
                            "Display": "Create a public folder",
                            "Customization": {
                                "Default": {
                                    "AddPublicFolder": true
                                }
                            }
                        },
                        {
                            "Display": "Remove a public folder",
                            "Customization": {
                                "Default": {
                                    "AddPublicFolder": false
                                },
                                "Hide": [
                                    "MailboxName"
                                ]
                            }
                        }
                    ]
                },
                "Default": "Create a public folder"
            },
            {
                "Name": "CallerName",
                "Hide": true
            },
            {
                "Name": "AddPublicFolder",
                "Hide": true,
                "DisplayName": "Create the folder?"
            },
            {
                "Name": "PublicFolderName",
                "DisplayName": "Public folder name"
            },
            {
                "Name": "MailboxName",
                "DisplayName": "Public folder mailbox"
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $PublicFolderName,
    [string] $MailboxName,
    [Parameter(Mandatory = $true)]
    [bool] $AddPublicFolder,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    Connect-RjRbExchangeOnline
    if ($AddPublicFolder) {
        "## Trying to create Public Folder '$PublicFolderName'"
        if ($MailboxName) {
            New-PublicFolder -Name $PublicFolderName -Mailbox $MailboxName | Out-Null
        }
        else {
            New-PublicFolder -Name $PublicFolderName | Out-Null
        }
        "## Public folder '$PublicFolderName' created."
    }
    else {
        "## Trying to remove Public Folder '$PublicFolderName'"
        $folder = Get-PublicFolder -Identity $PublicFolderName -ErrorAction SilentlyContinue
        if (-not $folder) {
            $folder = Get-PublicFolder -Identity ("\" + $PublicFolderName) -ErrorAction SilentlyContinue
        }
        if ($folder) {
            Remove-PublicFolder -Identity ($folder.Identity) -Confirm:$false | Out-Null
            "## Public folder '$PublicFolderName' removed."
        }
        else {
            "## Public folder '$PublicFolderName' not found."
            throw "not found"
        }
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}