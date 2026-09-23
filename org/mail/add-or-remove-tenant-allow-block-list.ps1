<#
    .SYNOPSIS
    Add or remove a Tenant Allow/Block List entry

    .DESCRIPTION
    Adds a sender, URL or file hash to the Tenant Allow/Block List of Defender for Office 365, or removes it again. New entries expire after the chosen number of days, so temporary exceptions clean themselves up.

    .PARAMETER Entry
    What to allow or block: a domain, an email address, a URL, or a file hash, matching the entry type.

    .PARAMETER ListType
    Sender takes a domain or email address, URL a web address, File hash a SHA-256 hash.

    .PARAMETER Block
    Block list rejects matching mail, URLs or files; Allow list lets them through even when Defender would filter them.

    .PARAMETER Remove
    Add the entry creates it with the chosen expiry; Remove the entry deletes the existing entry with the same value.

    .PARAMETER DaysToExpire
    Days until a new entry expires and is removed automatically.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "ParameterList": [
            {
                "Name": "Entry",
                "DisplayName": "Entry"
            },
            {
                "Name": "ListType",
                "DisplayName": "Entry type",
                "Select": {
                    "Options": [
                        {
                            "Display": "Sender (domain or email address)",
                            "ParameterValue": "Sender"
                        },
                        {
                            "Display": "URL",
                            "ParameterValue": "Url"
                        },
                        {
                            "Display": "File hash",
                            "ParameterValue": "FileHash"
                        }
                    ],
                    "ShowValue": false
                }
            },
            {
                "Name": "Block",
                "DisplayName": "List",
                "Select": {
                    "Options": [
                        {
                            "Display": "Allow list",
                            "ParameterValue": false
                        },
                        {
                            "Display": "Block list",
                            "ParameterValue": true
                        }
                    ],
                    "ShowValue": false
                }
            },
            {
                "Name": "Remove",
                "DisplayName": "Action",
                "Select": {
                    "Options": [
                        {
                            "Display": "Add the entry",
                            "ParameterValue": false
                        },
                        {
                            "Display": "Remove the entry",
                            "ParameterValue": true
                        }
                    ],
                    "ShowValue": false
                }
            },
            {
                "Name": "DaysToExpire",
                "DisplayName": "Days until expiry"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $Entry,
    [ValidateSet("Sender", "Url", "FileHash")]
    [string] $ListType = "Sender",
    [bool] $Block = $true,
    [bool] $Remove = $false,
    [int] $DaysToExpire = 30,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Entry: $Entry" -Verbose
Write-RjRbLog -Message "ListType: $ListType" -Verbose
Write-RjRbLog -Message "Block: $Block" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "DaysToExpire: $DaysToExpire" -Verbose
Write-RjRbLog -Message "CallerName: $CallerName" -Verbose

#endregion

########################################################
#region     Main Part
########################################################

try {
    #region Connect and get existing entries
    Connect-RjRbExchangeOnline

    # Check if the entry already exists
    $existingEntry = $null
    try {
        $allEntries = Get-TenantAllowBlockListItems -ListType $ListType -ErrorAction SilentlyContinue
        $existingEntry = $allEntries | Where-Object { $_.Value -eq $Entry }
    }
    catch {
        Write-RjRbLog -Message "Could not retrieve existing entries: $_" -Verbose
    }
    #endregion

    #region    Determine Action and Execute
    # Determine action type
    $ActionType = if ($Block) { "Block" } else { "Allow" }

    # Calculate expiration date
    $ExpirationDate = (Get-Date).AddDays($DaysToExpire)

    if ($Remove) {
        # Remove the entry
        if (-not $existingEntry) {
            Write-Output "Entry '$($Entry)' does not exist in the $($ListType) $($ActionType) list. Nothing to remove."
            exit
        }

        Write-Output "Removing entry '$($Entry)' from $($ListType) list"

        Remove-TenantAllowBlockListItems -ListType $ListType -Entries $Entry -ErrorAction Stop | Out-Null

        Write-Output "Successfully removed '$($Entry)' from the $($ListType) $($ActionType) list."
    }
    else {
        # Add the entry
        if ($existingEntry) {
            Write-Output "Entry '$($Entry)' already exists in the $($ListType) list."
            Write-Output "Existing entry details:"
            Write-Output "- Action: $($existingEntry.Action)"
            Write-Output "- Expiration Date: $($existingEntry.ExpirationDate)"
            Write-Output "- Submission ID: $($existingEntry.SubmissionID)"
            Write-Output ""
            Write-Output "To update the entry, please remove it first and then add it again."
            exit
        }

        Write-RjRbLog -Message "Adding entry '$Entry' to $ListType $ActionType list with expiration date $ExpirationDate" -Verbose

        if ($Block) {
            New-TenantAllowBlockListItems -ListType $ListType -Block -Entries $Entry -ExpirationDate $ExpirationDate -ErrorAction Stop | Out-Null
            Write-Output "Successfully added '$($Entry)' to the $($ListType) Block list (expires: $($ExpirationDate.ToString('yyyy-MM-dd')))."
        }
        else {
            New-TenantAllowBlockListItems -ListType $ListType -Allow -Entries $Entry -ExpirationDate $ExpirationDate -ErrorAction Stop | Out-Null
            Write-Output "Successfully added '$($Entry)' to the $($ListType) Allow list (expires: $($ExpirationDate.ToString('yyyy-MM-dd')))."
        }
    }
    #endregion
}
catch {
    Write-RjRbLog -Message "Error: $_" -ErrorRecord $_
    throw $_
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
#endregion