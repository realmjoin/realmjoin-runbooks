<#
    .SYNOPSIS
    List group memberships for this user

    .DESCRIPTION
    Lists group memberships for this user and supports filtering by group type, membership type, role-assignable status, Teams enablement, source, and writeback status. Outputs the results as CSV-formatted text.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER GroupType
    Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default).

    .PARAMETER MembershipType
    Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default).

    .PARAMETER RoleAssignable
    Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default).

    .PARAMETER TeamsEnabled
    Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default).

    .PARAMETER Source
    Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default).

    .PARAMETER WritebackEnabled
    Filter groups by writeback enablement.

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
    [ValidateSet("Security", "M365", "All")]
    [string] $GroupType = "All",
    [ValidateSet("Assigned", "Dynamic", "All")]
    [string] $MembershipType = "All",
    [ValidateSet("Yes", "NotSet")]
    [string] $RoleAssignable = "NotSet",
    [ValidateSet("Yes", "NotSet")]
    [string] $TeamsEnabled = "NotSet",
    [ValidateSet("Cloud", "OnPrem", "All")]
    [string] $Source = "All",
    [ValidateSet("Yes", "No", "All")]
    [string] $WritebackEnabled = "All",

    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "user-group-memberships",

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

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "GroupType: $GroupType" -Verbose
Write-RjRbLog -Message "MembershipType: $MembershipType" -Verbose
Write-RjRbLog -Message "RoleAssignable: $RoleAssignable" -Verbose
Write-RjRbLog -Message "TeamsEnabled: $TeamsEnabled" -Verbose
Write-RjRbLog -Message "Source: $Source" -Verbose
Write-RjRbLog -Message "WritebackEnabled: $WritebackEnabled" -Verbose
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

try {
    Write-Output "Connecting to Microsoft Graph (RealmJoin)..."
    Connect-RjRbGraph
}
catch {
    Write-Error "Failed to connect to Microsoft Graph (RealmJoin): $_"
    throw $_
}

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

# Get all group memberships with all needed fields
$MemberGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/memberOf/microsoft.graph.group" -OdSelect "id,displayName,mailEnabled,securityEnabled,groupTypes,membershipRule,isAssignableToRole,resourceProvisioningOptions,onPremisesSyncEnabled,writebackConfiguration" -FollowPaging

if ($MemberGroups) {
    $FilteredGroups = $MemberGroups | Where-Object {
        $group = $_

        # Determine if it's a Security or M365 group
        $isSecurityGroup = $group.securityEnabled -and -not $group.mailEnabled
        $isM365Group = $group.mailEnabled -and ($group.groupTypes -contains "Unified")

        # Determine if it's Assigned or Dynamic
        $isDynamic = $null -ne $group.membershipRule -and $group.membershipRule -ne ""
        $isAssigned = -not $isDynamic

        # Apply Group Type filter
        $groupTypeMatch = $false
        switch ($GroupType) {
            "Security" { $groupTypeMatch = $isSecurityGroup }
            "M365" { $groupTypeMatch = $isM365Group }
            "All" { $groupTypeMatch = $true }
        }

        # Apply Membership Type filter
        $membershipTypeMatch = $false
        switch ($MembershipType) {
            "Assigned" { $membershipTypeMatch = $isAssigned }
            "Dynamic" { $membershipTypeMatch = $isDynamic }
            "All" { $membershipTypeMatch = $true }
        }

        # Apply RoleAssignable filter
        $roleAssignableMatch = $true
        if ($RoleAssignable -eq "Yes") {
            $roleAssignableMatch = $group.isAssignableToRole -eq $true
        }

        # Apply TeamsEnabled filter
        $teamsEnabledMatch = $true
        if ($TeamsEnabled -eq "Yes") {
            $teamsEnabledMatch = $group.resourceProvisioningOptions -contains "Team"
        }

        # Apply Source filter
        $sourceMatch = $true
        switch ($Source) {
            "Cloud" { $sourceMatch = -not $group.onPremisesSyncEnabled }
            "OnPrem" { $sourceMatch = $group.onPremisesSyncEnabled -eq $true }
            "All" { $sourceMatch = $true }
        }

        # Apply WritebackEnabled filter
        $writebackMatch = $true
        switch ($WritebackEnabled) {
            "Yes" { $writebackMatch = $group.writebackConfiguration.isEnabled -eq $true }
            "No" { $writebackMatch = -not $group.writebackConfiguration.isEnabled }
            "All" { $writebackMatch = $true }
        }

        return $groupTypeMatch -and $membershipTypeMatch -and $roleAssignableMatch -and $teamsEnabledMatch -and $sourceMatch -and $writebackMatch
    }

    if ($FilteredGroups) {
        # Store filtered groups in a variable to prevent pipeline issues
        $GroupsList = @($FilteredGroups)

        # Build a structured report object per group (used for console output, CSV file, and email)
        $reportData = foreach ($Group in $GroupsList) {
            # Determine group type for display
            $displayGroupType = ""
            if ($Group.securityEnabled -and -not $Group.mailEnabled) {
                $displayGroupType = "Security"
            } elseif ($Group.mailEnabled -and ($Group.groupTypes -contains "Unified")) {
                $displayGroupType = "M365"
            } elseif ($Group.mailEnabled) {
                $displayGroupType = "Distribution"
            } else {
                $displayGroupType = "Other"
            }

            [PSCustomObject]@{
                DisplayName      = $Group.displayName
                ID               = $Group.id
                Type             = $displayGroupType
                MembershipType   = if ($Group.membershipRule) { "Dynamic" } else { "Assigned" }
                RoleAssignable   = if ($Group.isAssignableToRole) { "Yes" } else { "No" }
                TeamsEnabled     = if ($Group.resourceProvisioningOptions -contains "Team") { "Yes" } else { "No" }
                Source           = if ($Group.onPremisesSyncEnabled) { "OnPrem" } else { "Cloud" }
                WritebackEnabled = if ($Group.writebackConfiguration.isEnabled) { "Yes" } else { "No" }
            }
        }
        $reportData = @($reportData)

        "## Listing group memberships for '$($User.UserPrincipalName)' with applied filters:"
        "## Filters Applied: Group Type: $($GroupType); Membership Type: $($MembershipType); Role Assignable: $($RoleAssignable); Teams Enabled: $($TeamsEnabled); Source: $($Source); Writeback: $($WritebackEnabled)"
        "## Found $($reportData.Count) group(s) matching the selected filters."
        ""
        # CSV Header - always include all columns
        "DisplayName,ID,Type,MembershipType,RoleAssignable,TeamsEnabled,Source,WritebackEnabled"

        foreach ($item in $reportData) {
            # Escape quotes in displayName if needed
            $escapedName = $item.DisplayName -replace '"', '""'
            if ($escapedName -match '[,"]') {
                $escapedName = "`"$escapedName`""
            }

            "$escapedName,$($item.ID),$($item.Type),$($item.MembershipType),$($item.RoleAssignable),$($item.TeamsEnabled),$($item.Source),$($item.WritebackEnabled)"
        }

    } else {
        $reportData = @()
        "## No groups found matching the selected filters."
    }
} else {
    $reportData = @()
    "## User is not a member of any groups."
}

#endregion

########################################################
#region     Output/Export, Upload and Email
########################################################

# The CSV file is only needed when it will be uploaded and/or attached to an email
$csvFilePath = $null
if (($SendMail -or $CreateDownloadLink) -and $reportData.Count -gt 0) {
    $csvFileName = "group-memberships_$($User.UserPrincipalName)_$(Get-Date -Format 'yyyyMMdd').csv"
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

    $subject = "Group Memberships - $($User.UserPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownContent = @"
# Group Memberships Report

**User:** $($User.UserPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Filters Applied
- Group Type: **$($GroupType)**
- Membership Type: **$($MembershipType)**
- Role Assignable: **$($RoleAssignable)**
- Teams Enabled: **$($TeamsEnabled)**
- Source: **$($Source)**
- Writeback: **$($WritebackEnabled)**

## Summary
- Groups matching the selected filters: **$($reportData.Count)**

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