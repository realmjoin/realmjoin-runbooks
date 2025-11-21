<#
  .SYNOPSIS
  Add or remove entries from the Tenant Allow/Block List.

  .DESCRIPTION
  Add or remove entries from the Tenant Allow/Block List in Microsoft Defender for Office 365.
  Allows blocking or allowing senders, URLs, or file hashes. A new entry is set to expire in 30 days by default.

  .PARAMETER Entry
  The entry to add or remove (e.g., domain, email address, URL, or file hash).

  .PARAMETER ListType
  The type of entry: Sender, Url, or FileHash.

  .PARAMETER Block
  Decides whether to block or allow the entry.

  .PARAMETER Remove
  Decides whether to remove or add the entry.

  .PARAMETER DaysToExpire
  Number of days until the entry expires. Default is 30 days.

  .INPUTS
    RunbookCustomization: {
        "ParameterList": [
            {
                "Name": "Entry",
                "DisplayName": "Entry (Domain, Email, URL, or Hash)"
            },
            {
                "Name": "ListType",
                "DisplayName": "Entry Type",
                "Select": {
                    "Options": [
                        {
                            "Display": "Sender (Domain or Email)",
                            "ParameterValue": "Sender"
                        },
                        {
                            "Display": "URL",
                            "ParameterValue": "Url"
                        },
                        {
                            "Display": "File Hash",
                            "ParameterValue": "FileHash"
                        }
                    ],
                    "ShowValue": false
                }
            },
            {
                "Name": "Block",
                "DisplayName": "List Type",
                "Select": {
                    "Options": [
                        {
                            "Display": "Allow List (permit entry)",
                            "ParameterValue": false
                        },
                        {
                            "Display": "Block List (block entry)",
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
                            "Display": "Add entry to the list",
                            "ParameterValue": false
                        },
                        {
                            "Display": "Remove entry from the list",
                            "ParameterValue": true
                        }
                    ],
                    "ShowValue": false
                }
            },
            {
                "Name": "DaysToExpire",
                "DisplayName": "Days to Expire"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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

$Version = "1.0.0"
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