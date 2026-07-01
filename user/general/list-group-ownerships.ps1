<#
    .SYNOPSIS
    List group ownerships for this user.

    .DESCRIPTION
    Lists Entra ID groups where the specified user is an owner. Outputs the group names and IDs.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER SendMail
    If enabled, the report is sent via email as a CSV attachment. Toggling this on reveals the recipient address field.

    .PARAMETER EmailTo
    Recipient address or multiple comma-separated addresses for the email report. Only used when SendMail is enabled.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER CreateDownloadLink
    If enabled, the report CSV is uploaded to an Azure Storage Account and a time-limited download link is returned in the output.

    .PARAMETER ContainerName
    Storage container name used for the upload.

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account.

    .PARAMETER StorageAccountName
    Storage account name used for the upload.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "SendMail": {
                "DisplayName": "Send the report via email?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo"]
                            }
                        }
                    ]
                }
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a file download link (upload report to storage)?",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)",
                "Hide": true
            },
            "EmailFrom": {
                "Hide": true
            },
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "LinkExpiryDays": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,

    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "user-group-ownerandmemberships",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
}
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# A recipient and a configured sender are required to send an email report
if ($SendMail) {
    if (-not $EmailTo) {
        throw "A recipient email address (EmailTo) is required when 'Send the report via email' is enabled."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
        throw "The sender email address (EmailFrom) needs to be configured in the runbook customization."
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Connect and Initialize
########################################################

Connect-RjRbGraph

if ($CreateDownloadLink) {
    try {
        Write-Output "Connecting to Azure (RealmJoin)..."
        Connect-RjRbAzAccount
    }
    catch {
        Write-Error "Failed to connect to Azure (RealmJoin): $_"
        throw $_
    }
}

#endregion

########################################################
#region     Main Code
########################################################

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/ownedObjects/microsoft.graph.group/" -FollowPaging

# Build a structured report object per owned group (used for console output, CSV file, and email)
$reportData = @()
if ($OwnedGroups) {
    $reportData = foreach ($OwnedGroup in $OwnedGroups) {
        $groupType = if ($OwnedGroup.groupTypes -contains "Unified") {
            "M365"
        } elseif ($OwnedGroup.securityEnabled -and -not $OwnedGroup.mailEnabled) {
            "Security"
        } elseif ($OwnedGroup.mailEnabled) {
            "Distribution"
        } else {
            "Other"
        }

        [PSCustomObject]@{
            DisplayName = $OwnedGroup.displayName
            ID          = $OwnedGroup.id
            Type        = $groupType
        }
    }
    $reportData = @($reportData)
}

"## Listing group ownerships for '$($User.UserPrincipalName)':"
if ($reportData.Count -gt 0) {
    foreach ($item in $reportData) {
        "## Group '$($item.DisplayName)' with id '$($item.ID)'"
    }
} else {
    "## User is not an owner of any groups."
}

#endregion

########################################################
#region     Output/Export, Upload and Email
########################################################

# The CSV file is only needed when it will be uploaded and/or attached to an email
$csvFilePath = $null
if (($SendMail -or $CreateDownloadLink) -and $reportData.Count -gt 0) {
    $csvFileName = "group-ownerships_$($User.UserPrincipalName)_$(Get-Date -Format 'yyyyMMdd').csv"
    $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
    $reportData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    Write-RjRbLog -Message "Exported $($reportData.Count) groups to CSV: $csvFilePath" -Verbose
}
elseif (($SendMail -or $CreateDownloadLink) -and $reportData.Count -eq 0) {
    Write-Output ""
    Write-Output "## No groups found - skipping CSV export, upload and email."
}

#region Upload / Download Link (optional)
##############################

if ($CreateDownloadLink -and $csvFilePath) {
    Write-Output ""
    Write-Output "## Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths @($csvFilePath) `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    $uploadResult = $uploadResults[0]
    Write-Output "## Report uploaded to storage account."
    Write-Output "## Expiry of Link: $($uploadResult.EndTime)"
    $uploadResult.SASLink | Out-String | Write-Output
}

#endregion Upload / Download Link

#region Send Email Report (optional)
##############################

if ($SendMail -and $csvFilePath) {
    Write-Output ""
    Write-Output "## Preparing email report to send to '$($EmailTo)'..."

    # Resolve tenant display name for the report header
    $tenantDisplayName = "Unknown Tenant"
    try {
        $tenantInfo = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "displayName"
        if ($tenantInfo -and $tenantInfo[0].displayName) {
            $tenantDisplayName = $tenantInfo[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }

    $subject = "Group Ownerships - $($User.UserPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownContent = @"
# Group Ownerships Report

**User:** $($User.UserPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups owned by the user: **$($reportData.Count)**

Details are attached as a CSV file for your review.
"@

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $subject -MarkdownContent $markdownContent -Attachments @($csvFilePath) -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-Output "## Email report sent successfully to: $($EmailTo)"
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

#endregion Send Email Report

#endregion

########################################################
#region     Cleanup
########################################################

if ($csvFilePath -and (Test-Path -Path $csvFilePath)) {
    try {
        Remove-Item -Path $csvFilePath -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not remove temporary CSV file '$csvFilePath': $_"
    }
}

if ($CreateDownloadLink) {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}

#endregion