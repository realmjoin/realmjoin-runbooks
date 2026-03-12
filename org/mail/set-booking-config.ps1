<#
        .SYNOPSIS
        Configure Microsoft Bookings settings for the organization

        .DESCRIPTION
        Configures Microsoft Bookings settings at the organization level using Exchange Online organization configuration. The runbook can optionally create an OWA mailbox policy for Bookings creators and disable Bookings in the default OWA policy.

        .PARAMETER BookingsEnabled
        If set to true, Microsoft Bookings is enabled for the organization.

        .PARAMETER BookingsAuthEnabled
        If set to true, Bookings uses authentication.

        .PARAMETER BookingsSocialSharingRestricted
        If set to true, social sharing is restricted.

        .PARAMETER BookingsExposureOfStaffDetailsRestricted
        If set to true, exposure of staff details is restricted.

        .PARAMETER BookingsMembershipApprovalRequired
        If set to true, membership approval is required.

        .PARAMETER BookingsSmsMicrosoftEnabled
        If set to true, Microsoft SMS notifications are enabled.

        .PARAMETER BookingsSearchEngineIndexDisabled
        If set to true, search engine indexing is disabled.

        .PARAMETER BookingsAddressEntryRestricted
        If set to true, address entry is restricted.

        .PARAMETER BookingsCreationOfCustomQuestionsRestricted
        If set to true, creation of custom questions is restricted.

        .PARAMETER BookingsNotesEntryRestricted
        If set to true, notes entry is restricted.

        .PARAMETER BookingsPhoneNumberEntryRestricted
        If set to true, phone number entry is restricted.

        .PARAMETER BookingsNamingPolicyEnabled
        If set to true, naming policies are enabled.

        .PARAMETER BookingsBlockedWordsEnabled
        If set to true, blocked words are enabled for naming policies.

        .PARAMETER BookingsNamingPolicyPrefixEnabled
        If set to true, the naming policy prefix is enabled.

        .PARAMETER BookingsNamingPolicyPrefix
        Prefix applied by the naming policy.

        .PARAMETER BookingsNamingPolicySuffixEnabled
        If set to true, the naming policy suffix is enabled.

        .PARAMETER BookingsNamingPolicySuffix
        Suffix applied by the naming policy.

        .PARAMETER CreateOwaPolicy
        If set to true, an OWA mailbox policy for Bookings creators is created if missing.

        .PARAMETER OwaPolicyName
        Name of the OWA mailbox policy to create or use for Bookings creators.

        .PARAMETER CallerName
        Caller name is tracked purely for auditing purposes.

        .INPUTS
        RunbookCustomization: {
                "Parameters": {
                        "CallerName": {
                                "Hide": true
                        }
                }
        }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param(
        [bool] $BookingsEnabled = $true,
        [bool] $BookingsAuthEnabled = $false,
        [bool] $BookingsSocialSharingRestricted = $false,
        [bool] $BookingsExposureOfStaffDetailsRestricted = $true,
        [bool] $BookingsMembershipApprovalRequired = $true,
        [bool] $BookingsSmsMicrosoftEnabled = $true,
        [bool] $BookingsSearchEngineIndexDisabled = $false,
        [bool] $BookingsAddressEntryRestricted = $false,
        [bool] $BookingsCreationOfCustomQuestionsRestricted = $false,
        [bool] $BookingsNotesEntryRestricted = $false,
        [bool] $BookingsPhoneNumberEntryRestricted = $false,
        [bool] $BookingsNamingPolicyEnabled = $true,
        [bool] $BookingsBlockedWordsEnabled = $false,
        [bool] $BookingsNamingPolicyPrefixEnabled = $true,
        [string] $BookingsNamingPolicyPrefix = "Booking-",
        [bool] $BookingsNamingPolicySuffixEnabled = $false,
        [string] $BookingsNamingPolicySuffix = "",
        [bool] $CreateOwaPolicy = $true,
        [string] $OwaPolicyName = "BookingsCreators",
        # CallerName is tracked purely for auditing purposes
        [Parameter(Mandatory = $true)]
        [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

$splatParams = @{
        BookingsEnabled                             = $BookingsEnabled
        BookingsAuthEnabled                         = $BookingsAuthEnabled
        BookingsSocialSharingRestricted             = $BookingsSocialSharingRestricted
        BookingsExposureOfStaffDetailsRestricted    = $BookingsExposureOfStaffDetailsRestricted
        BookingsMembershipApprovalRequired          = $BookingsMembershipApprovalRequired
        BookingsSmsMicrosoftEnabled                 = $BookingsSmsMicrosoftEnabled
        BookingsSearchEngineIndexDisabled           = $BookingsSearchEngineIndexDisabled
        BookingsAddressEntryRestricted              = $BookingsAddressEntryRestricted
        BookingsCreationOfCustomQuestionsRestricted = $BookingsCreationOfCustomQuestionsRestricted
        BookingsNotesEntryRestricted                = $BookingsNotesEntryRestricted
        BookingsPhoneNumberEntryRestricted          = $BookingsPhoneNumberEntryRestricted
        BookingsNamingPolicyEnabled                 = $BookingsNamingPolicyEnabled
        BookingsBlockedWordsEnabled                 = $BookingsBlockedWordsEnabled
        BookingsNamingPolicyPrefixEnabled           = $BookingsNamingPolicyPrefixEnabled
        BookingsNamingPolicyPrefix                  = $BookingsNamingPolicyPrefix
        BookingsNamingPolicySuffixEnabled           = $BookingsNamingPolicySuffixEnabled
        BookingsNamingPolicySuffix                  = $BookingsNamingPolicySuffix
}

Connect-RjRbExchangeOnline

Set-OrganizationConfig @splatParams

"## MS Bookings has been configured with these values:"
$splatParams | Format-Table -AutoSize | Out-String

if ($CreateOwaPolicy) {
        if (get-owaMailboxPolicy -Identity $OwaPolicyName -ErrorAction SilentlyContinue) {
                "## OWA Policy '$OwaPolicyName' already exists. Skipping."
        }
        else {
                New-OwaMailboxPolicy -Name $OwaPolicyName | Out-Null
                "## New OWA Policy '$OwaPolicyName' created."
        }
        Set-OwaMailboxPolicy "OwaMailboxPolicy-Default" -BookingsMailboxCreationEnabled:$false | Out-Null
        "## Disabled Bookings in default OWA policy."
}

Disconnect-ExchangeOnline -Confirm:$false