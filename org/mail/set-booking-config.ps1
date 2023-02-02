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
        [bool] $BookingsNamingPolicySuffixEnabled  = $false,
        [string] $BookingsNamingPolicySuffix = "",
        # CallerName is tracked purely for auditing purposes
        [Parameter(Mandatory = $true)]
        [string] $CallerName    
)

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$splatParams = @{
        BookingsEnabled = $BookingsEnabled
        BookingsAuthEnabled = $BookingsAuthEnabled
        BookingsSocialSharingRestricted = $BookingsSocialSharingRestricted
        BookingsExposureOfStaffDetailsRestricted = $BookingsExposureOfStaffDetailsRestricted
        BookingsMembershipApprovalRequired = $BookingsMembershipApprovalRequired
        BookingsSmsMicrosoftEnabled = $BookingsSmsMicrosoftEnabled
        BookingsSearchEngineIndexDisabled = $BookingsSearchEngineIndexDisabled
        BookingsAddressEntryRestricted = $BookingsAddressEntryRestricted
        BookingsCreationOfCustomQuestionsRestricted = $BookingsCreationOfCustomQuestionsRestricted
        BookingsNotesEntryRestricted = $BookingsNotesEntryRestricted
        BookingsPhoneNumberEntryRestricted = $BookingsPhoneNumberEntryRestricted
        BookingsNamingPolicyEnabled = $BookingsNamingPolicyEnabled
        BookingsBlockedWordsEnabled = $BookingsBlockedWordsEnabled
        BookingsNamingPolicyPrefixEnabled = $BookingsNamingPolicyPrefixEnabled
        BookingsNamingPolicyPrefix = $BookingsNamingPolicyPrefix
        BookingsNamingPolicySuffixEnabled = $BookingsNamingPolicySuffixEnabled
        BookingsNamingPolicySuffix = $BookingsNamingPolicySuffix
}

Connect-RjRbExchangeOnline

Set-OrganizationConfig @splatParams

"## MS Bookings has been configured with these values:"
$splatParams | Format-Table -AutoSize | Out-String

Disconnect-ExchangeOnline -Confirm:$false 