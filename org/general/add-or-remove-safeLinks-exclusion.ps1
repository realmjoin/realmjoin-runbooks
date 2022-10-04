<#
  .SYNOPSIS
  Add or remove a SafeLinks URL exclusion to/from a given policy.

  .DESCRIPTION
  Add or remove a SafeLinks URL exclusion to/from a given policy.
  It can also be used to initially create a new policy if required.

  .PARAMETER LinkPattern
  URL to allow, can contain '*' as wildcard for host and paths

  .PARAMETER PolicyName
  Optional, will overwrite default values

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "Action": {
            "DisplayName": "Add or Remove URL Pattern to/from Policy",
            "Select": {
                "Options": 
                [
                    {
                        "Display": "Add URL Pattern to Policy" ,
                        "ParameterValue": 0
                    },
                    {
                        "Display": "Remove URL Pattern from Policy",
                        "ParameterValue": 1,
                        "Customization": {
                            "Hide": [
                                "CreateNewPolicyIfNeeded"
                            ]
                        }
                    },
                    {
                        "Display": "List all existing policies and settings",
                        "ParameterValue": 2,
                        "Customization": {
                            "Hide": [
                                "LinkPattern",
                                "CreateNewPolicyIfNeeded",
                                "PolicyName"
                            ]
                        }
                    }
                ]
            }
        },
        "DefaultPolicyName": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Action to execute" } )]
    [int] $Action = 2,
    # Not mandatory to allow an example value
    [String] $LinkPattern = "https://*.microsoft.com/*",
    # If only one policy exists, no need to specify. Will use "DefaultPolicyName" as default otherwise.
    [Parameter(Mandatory = $true)]
    [String] $DefaultPolicyName = "Default SafeLinks Policy",
    # Using "PolicyName" will overwrite the defaults
    [ValidateScript( { Use-RJInterface -DisplayName "Safe Links policy name" } )]
    [String] $PolicyName,
    [boolean] $CreateNewPolicyIfNeeded = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

function createGroupFromPolicyName {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PolicyGroupName
    )

    # Check if group exists already
    $mailNickName = "$($PolicyGroupName.replace(' ',''))Users"
    $group = get-group -Identity $mailNickName -ErrorAction SilentlyContinue
    if ($group) {
        throw "Group '$mailNickName' already exists."
    }

    $groupDescription = @{
        Name        = $mailNickName
        DisplayName = "$($PolicyGroupName) Users"
        Type        = "Security"
        Notes       = "Add users to apply '$PolicyGroupName' to them"
    }

    $groupObj = New-DistributionGroup @groupDescription

    return $groupObj
    
}

function createSafeLinksPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SafeLinksPolName,
        [string] $GroupName = "$SafeLinksPolName Users"
    )

    $policyDescription = @{
        Name                       = $SafeLinksPolName
        AdminDisplayName           = "Default SafeLinks Policy - created by RealmJoin"
        IsEnabled                  = $true
        AllowClickThrough          = $false
        DoNotAllowClickThrough     = $true
        ScanUrls                   = $true 
        EnableForInternalSenders   = $true
        DeliverMessageAfterScan    = $true
        EnableOrganizationBranding = $true
        TrackClicks                = $true
        DoNotTrackUserClicks       = $false
        EnableSafeLinksForTeams    = $false
        DisableUrlRewrite          = $false
    }

    $policy = New-SafeLinksPolicy @policyDescription
    
    # The Web Portal actually shows "rules" not the "policies" - so we name them identically
    New-SafeLinksRule -name $SafeLinksPolName -SafeLinksPolicy $SafeLinksPolName -SentToMemberOf $GroupName | Out-Null

    return $policy
}

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

try {
    Connect-RjRbExchangeOnline

    if ($Action -eq 2) {
        $policies = [array](Get-SafeLinksPolicy -ErrorAction SilentlyContinue)
        "## Available Policies:"
        $policies | ForEach-Object {
            ""
            "## Policy name: $($_.Name)"
            $_ | Select-Object -Property IsEnabled, AllowClickThrough, DoNotAllowClickThrough, ScanUrls, EnableForInternalSenders, DeliverMessageAfterScan, EnableOrganizationBranding, TrackClicks, DoNotTrackUserClicks, EnableSafeLinksForTeams, DisableUrlRewrite, DoNotRewriteUrls | Format-List | Out-String
        }
        
        exit
    }
    
    $policy = $null

    # Work using a required Policy Name
    if ($PolicyName) {
        $policy = Get-SafeLinksPolicy -Identity $PolicyName -ErrorAction SilentlyContinue
        
        if (-not $policy) {
            "## Policy '$PolicyName' not found."
            # Remove...
            if ($Action -eq 1) {
                "## Exiting - nothing to do."
                exit
            }
            else {
                if ($CreateNewPolicyIfNeeded) {
                    # Add
                    "## Creating new policy '$PolicyName'"

                    ""
                    $groupObj = createGroupFromPolicyName -PolicyGroupName $PolicyName
                    "## Created group '$($groupObj.Name)'"
                    "## Add users to this group to apply SafeLinks to them."
            
                    ""
                    "## Creating SafeLinks Policy from template"
                    $policy = createSafeLinksPolicy -SafeLinksPolName $PolicyName -GroupName $groupObj.Name
                }
                else {
                    "## Policy '$PolicyName' not found."
                    ""
                    throw("Policy not found")
                }
            }
        }
    } 

    # Is our default policy available?
    if ((-not $policy) -and $DefaultPolicyName) {
        $policy = Get-SafeLinksPolicy -Identity $DefaultPolicyName -ErrorAction SilentlyContinue

        if (-not $policy) {
            "## Policy '$DefaultPolicyName' not found."

            $policies = [array](Get-SafeLinksPolicy -ErrorAction SilentlyContinue)

            # Do we have exactly one policy in this tenant?
            if ($policies.count -eq 1) {
                $policy = $policies[0]
            }
            # Multiple policies exist, but do not match
            if ($policies.count -gt 1) {
                "## Multiple policies available. Please select one."
                ""
                "## Available policies:"
                ""
                $policies | ForEach-Object {
                    "## Policy name: $($_.Name)"
                    $_ | Select-Object -Property IsEnabled, AllowClickThrough, DoNotAllowClickThrough, ScanUrls, EnableForInternalSenders, DeliverMessageAfterScan, EnableOrganizationBranding, TrackClicks, DoNotTrackUserClicks, EnableSafeLinksForTeams, DisableUrlRewrite, DoNotRewriteUrls | Format-List | Out-String
                    ""
                }
                throw ("Policy not selected")
            }
            # No policies available...
            if (($policies).count -eq 0) {
                "## No SafeLinks Policies exist/found."
                if ($Action -eq 1) {
                    # Remove
                    "## Exiting - nothing to do."
                    exit
                }
                else {
                    # Add
                    if ($CreateNewPolicyIfNeeded) {
                        "## Creating new policy '$DefaultPolicyName'"

                        ""
                        $groupObj = createGroupFromPolicyName -PolicyGroupName $DefaultPolicyName
                        "## Created group '$($groupObj.Name)'"
                        "## Add users to this group to apply SafeLinks to them."
            
                        ""
                        "## Creating SafeLinks Policy from template"
                        $policy = createSafeLinksPolicy -SafeLinksPolName $DefaultPolicyName -GroupName $groupObj.Name
                    }
                    else {
                        ""
                        throw("Policy not found")
                    }
                }
            }
        }
    }

    # failsafe...
    if (-not $policy) {
        "## Policy not found. Please provide a SafeLinks policy."
        ""
        $policies = [array](Get-SafeLinksPolicy -ErrorAction SilentlyContinue)
        "## Available policies:"
        ""
        $policies | ForEach-Object {
            "## Policy name: $($_.Name)"
            $_ | Select-Object -Property IsEnabled, AllowClickThrough, DoNotAllowClickThrough, ScanUrls, EnableForInternalSenders, DeliverMessageAfterScan, EnableOrganizationBranding, TrackClicks, DoNotTrackUserClicks, EnableSafeLinksForTeams, DisableUrlRewrite, DoNotRewriteUrls | Format-List | Out-String
            ""
        }
        throw("Policy not found or created")
    }

    "## Using policy '$($policy.name)'"

    ""
    "## Current list of URLs excluded from Safe Links:"
    $policy.DoNotRewriteUrls

    ""
    $DoNotRewriteUrls = @()
    if ($Remove) {
        "## Trying to remove $LinkPattern ..."
        foreach ($entry in $policy.DoNotRewriteUrls) {
            if ($entry -ne $LinkPattern) {
                $DoNotRewriteUrls += $entry
            } 
        }
    }
    else {
        "## Trying to add $LinkPattern ..."
        $DoNotRewriteUrls = $policy.DoNotRewriteUrls + $LinkPattern | Sort-Object -Unique
    }
    Set-SafeLinksPolicy -Identity $policy.Id -DoNotRewriteUrls $DoNotRewriteUrls | Out-Null
    "## Policy $policy successfully updated."

    ""
    "## Safe Links Policy Dump"
    Get-SafeLinksPolicy -Identity $policy.Id | Format-List | Out-String

}

finally {
    Disconnect-ExchangeOnline -confirm:$false | Out-Null
}