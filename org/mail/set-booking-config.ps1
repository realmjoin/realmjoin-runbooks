<#
        .SYNOPSIS
        Configure the Microsoft Bookings settings of the tenant

        .DESCRIPTION
        Sets the tenant-wide Microsoft Bookings settings in Exchange Online, such as whether Bookings is on, what customers may enter and how booking pages are named. Optionally an Outlook web policy for Bookings creators is created and Bookings is turned off in the default policy, so only members of that policy can create booking pages.

        .PARAMETER BookingsEnabled
        Turns Microsoft Bookings on for the tenant.

        .PARAMETER BookingsAuthEnabled
        Customers must sign in before they can book.

        .PARAMETER BookingsSocialSharingRestricted
        Removes the social sharing options from booking pages.

        .PARAMETER BookingsExposureOfStaffDetailsRestricted
        Keeps staff details such as email addresses off the booking pages.

        .PARAMETER BookingsMembershipApprovalRequired
        Staff must approve before they are added to a booking page.

        .PARAMETER BookingsSmsMicrosoftEnabled
        Customers can get SMS notifications about their bookings.

        .PARAMETER BookingsSearchEngineIndexDisabled
        Keeps booking pages out of search engine results.

        .PARAMETER BookingsAddressEntryRestricted
        Customers cannot enter their address when booking.

        .PARAMETER BookingsCreationOfCustomQuestionsRestricted
        Staff cannot add custom questions to booking forms.

        .PARAMETER BookingsNotesEntryRestricted
        Customers cannot add notes when booking.

        .PARAMETER BookingsPhoneNumberEntryRestricted
        Customers cannot enter their phone number when booking.

        .PARAMETER BookingsNamingPolicyEnabled
        Applies the prefix, suffix and blocked words rules to new booking page names.

        .PARAMETER BookingsBlockedWordsEnabled
        Rejects booking page names that contain a word from the blocked words list of the Microsoft 365 groups naming policy.

        .PARAMETER BookingsNamingPolicyPrefixEnabled
        Adds the prefix to every new booking page name.

        .PARAMETER BookingsNamingPolicyPrefix
        Text put in front of new booking page names.

        .PARAMETER BookingsNamingPolicySuffixEnabled
        Adds the suffix to every new booking page name.

        .PARAMETER BookingsNamingPolicySuffix
        Text appended to new booking page names.

        .PARAMETER CreateOwaPolicy
        Creates the Outlook web policy for Bookings creators if it is missing and turns off Bookings in the default policy.

        .PARAMETER OwaPolicyName
        Name of the Outlook web policy for Bookings creators.

        .PARAMETER CallerName
        Name of the user who started the runbook. Set by the portal and recorded for auditing.

        .INPUTS
        RunbookCustomization: {
                "Parameters": {
                        "BookingsEnabled": {
                                "DisplayName": "Enable Bookings?"
                        },
                        "BookingsAuthEnabled": {
                                "DisplayName": "Require sign-in to book?"
                        },
                        "BookingsSocialSharingRestricted": {
                                "DisplayName": "Hide social sharing?"
                        },
                        "BookingsExposureOfStaffDetailsRestricted": {
                                "DisplayName": "Hide staff details?"
                        },
                        "BookingsMembershipApprovalRequired": {
                                "DisplayName": "Require staff approval?"
                        },
                        "BookingsSmsMicrosoftEnabled": {
                                "DisplayName": "Allow SMS notifications?"
                        },
                        "BookingsSearchEngineIndexDisabled": {
                                "DisplayName": "Hide from search engines?"
                        },
                        "BookingsAddressEntryRestricted": {
                                "DisplayName": "Block address entry?"
                        },
                        "BookingsCreationOfCustomQuestionsRestricted": {
                                "DisplayName": "Block custom questions?"
                        },
                        "BookingsNotesEntryRestricted": {
                                "DisplayName": "Block notes entry?"
                        },
                        "BookingsPhoneNumberEntryRestricted": {
                                "DisplayName": "Block phone number entry?"
                        },
                        "BookingsNamingPolicyEnabled": {
                                "DisplayName": "Enable naming policy?"
                        },
                        "BookingsBlockedWordsEnabled": {
                                "DisplayName": "Enable blocked words?"
                        },
                        "BookingsNamingPolicyPrefixEnabled": {
                                "DisplayName": "Add prefix?"
                        },
                        "BookingsNamingPolicyPrefix": {
                                "DisplayName": "Prefix"
                        },
                        "BookingsNamingPolicySuffixEnabled": {
                                "DisplayName": "Add suffix?"
                        },
                        "BookingsNamingPolicySuffix": {
                                "DisplayName": "Suffix"
                        },
                        "CreateOwaPolicy": {
                                "DisplayName": "Create Outlook web policy for creators?"
                        },
                        "OwaPolicyName": {
                                "DisplayName": "Outlook web policy name"
                        },
                        "CallerName": {
                                "Hide": true
                        }
                }
        }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

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

$Version = "1.0.1"
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