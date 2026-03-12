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

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "GroupType: $GroupType" -Verbose
Write-RjRbLog -Message "MembershipType: $MembershipType" -Verbose
Write-RjRbLog -Message "RoleAssignable: $RoleAssignable" -Verbose
Write-RjRbLog -Message "TeamsEnabled: $TeamsEnabled" -Verbose
Write-RjRbLog -Message "Source: $Source" -Verbose
Write-RjRbLog -Message "WritebackEnabled: $WritebackEnabled" -Verbose

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

        "## Listing group memberships for '$($User.UserPrincipalName)' with applied filters:"
        "## Filters Applied: Group Type: $($GroupType); Membership Type: $($MembershipType); Role Assignable: $($RoleAssignable); Teams Enabled: $($TeamsEnabled); Source: $($Source); Writeback: $($WritebackEnabled)"
        "## Found $($GroupsList.Count) group(s) matching the selected filters."
        ""
        # CSV Header - always include all columns
        "DisplayName,ID,Type,MembershipType,RoleAssignable,TeamsEnabled,Source,WritebackEnabled"

        foreach ($Group in $GroupsList) {
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

            # Determine membership type for display
            $displayMembershipType = if ($Group.membershipRule) { "Dynamic" } else { "Assigned" }

            # Determine RoleAssignable
            $displayRoleAssignable = if ($Group.isAssignableToRole) { "Yes" } else { "No" }

            # Determine TeamsEnabled
            $displayTeamsEnabled = if ($Group.resourceProvisioningOptions -contains "Team") { "Yes" } else { "No" }

            # Determine Source
            $displaySource = if ($Group.onPremisesSyncEnabled) { "OnPrem" } else { "Cloud" }

            # Determine WritebackEnabled
            $displayWriteback = if ($Group.writebackConfiguration.isEnabled) { "Yes" } else { "No" }

            # Escape quotes in displayName if needed
            $escapedName = $Group.displayName -replace '"', '""'
            if ($escapedName -match '[,"]') {
                $escapedName = "`"$escapedName`""
            }

            "$escapedName,$($Group.id),$displayGroupType,$displayMembershipType,$displayRoleAssignable,$displayTeamsEnabled,$displaySource,$displayWriteback"
        }

    } else {
        "## No groups found matching the selected filters."
    }
} else {
    "## User is not a member of any groups."
}

#endregion