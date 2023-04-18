<#
.SYNOPSIS 
    Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

.NOTES
 Permissions (Graph):
    - DeviceManagementConfiguration.Read.All
    - Policy.Read.All
 Permissions AzureRM:
    - Storage Account Contributor

.INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules Microsoft.Graph.Authentication

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "TenantPolicyReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Also export raw JSON policies?" } )]
    [bool] $exportJson = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

function ConvertToMarkdown-PolicyAssignments {
    param(
        $assignments
    )

    "| Assignment | Target |"
    "|-|-|"
    # enumerate the assignments, will not do anything if there are no assignments
    foreach ($assignment in $assignments.value) {
        if (($assignment.target.'@odata.type' -eq "#microsoft.graph.groupAssignmentTarget") -or ($assignment.target.'@odata.type' -eq "#microsoft.graph.includeDeviceGroupsAssignmentTarget") -or ($assignment.target.'@odata.type' -eq "#microsoft.graph.includeUsersAssignmentTarget")) {
            try {
                $groupID = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/groups/$($assignment.target.groupId)?`$select=displayName" 
            }
            catch {}
            if ($assignment.target.deviceAndAppManagementAssignmentFilterType -ne "none") {
                $filter = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$($assignment.target.deviceAndAppManagementAssignmentFilterId)?`$select=displayName"
                "| Included Groups | $($groupID.displayName), Filter ($($assignment.target.deviceAndAppManagementAssignmentFilterType)): $($filter.displayName) |"
            }
            else {
                "| Included Groups | $($groupID.displayName) |"
            }
        }
        #Include all users
        elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") {
            if ($assignment.target.deviceAndAppManagementAssignmentFilterType -ne "none") {
                $filter = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$($assignment.target.deviceAndAppManagementAssignmentFilterId)?`$select=displayName"
                "| Included | All Users, Filter ($($assignment.target.deviceAndAppManagementAssignmentFilterType)): $($filter.displayName) |"
            }
            else {
                "| Included | All Users |"
            }
        }
        # Include all devices
        elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") {
            if ($assignment.target.deviceAndAppManagementAssignmentFilterType -ne "none") {
                $filter = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$($assignment.target.deviceAndAppManagementAssignmentFilterId)?`$select=displayName"
                "| Included | All Devices, Filter ($($assignment.target.deviceAndAppManagementAssignmentFilterType)): $($filter.displayName) |"
            }
            else {
                "| Included | All Devices |"
            }
        }
        elseif (($assignment.target.'@odata.type' -eq "#microsoft.graph.exclusionGroupAssignmentTarget") -or ($assignment.target.'@odata.type' -eq "microsoft.graph.allDevicesExcludingGroupsAssignmentTarget")) {
            try {
                $groupID = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/groups/$($assignment.target.groupId)?`$select=displayName" 
            }
            catch {}
            if ($assignment.target.deviceAndAppManagementAssignmentFilterType -ne "none") {
                $filter = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$($assignment.target.deviceAndAppManagementAssignmentFilterId)?`$select=displayName"
                "| Excluded Groups | $($groupID.displayName), Filter ($($assignment.target.deviceAndAppManagementAssignmentFilterType)): $($filter.displayName) |"
            }
            else {
                "| Excluded Groups | $($groupID.displayName) |"
            }
        
        }

    }

}

function ConvertToMarkdown-CompliancePolicy {
    # https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies

    # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windows10compliancepolicy?view=graph-rest-1.0
    # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-ioscompliancepolicy?view=graph-rest-1.0
    # ... More if needed according to BluePrint

    # Still missing:
    # - grace period (scheduled actions)
    # - assignments

    param(
        $policy
    )

    "### $($policy.displayName)"
    ""

    #$propHash = Get-Content -Path ".\compliancePolicyPropertiesHashtable.json" | ConvertFrom-Json -Depth 100
    $propHashJSON = @'
    {
        "#microsoft.graph.aospDeviceOwnerCompliancePolicy": {
          "passwordRequiredType": "Type of characters in password. Possible values are: deviceDefault, required, numeric, numericComplex, alphabetic, alphanumeric, alphanumericWithSymbols, lowSecurityBiometric, customPassword.",
          "minAndroidSecurityPatchLevel": "Minimum Android security patch level.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "osMinimumVersion": "Minimum Android version.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "securityBlockJailbrokenDevices": "Devices must not be jailbroken or rooted.",
          "passwordRequired": "Require a password to unlock device.",
          "osMaximumVersion": "Maximum Android version.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required. Valid values 1 to 8640.",
          "storageRequireEncryption": "Require encryption on Android devices.",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16."
        },
        "#microsoft.graph.macOSCompliancePolicy": {
          "passwordRequired": "Whether or not to require a password.",
          "osMinimumVersion": "Minimum MacOS version.",
          "passwordBlockSimple": "Indicates whether or not to block simple passwords.",
          "osMaximumVersion": "Maximum MacOS version.",
          "systemIntegrityProtectionEnabled": "Require that devices have enabled system integrity protection.",
          "gatekeeperAllowedAppSource": "System and Privacy setting that determines which download locations apps can be run from on a macOS device. Possible values are: notConfigured, macAppStore, macAppStoreAndIdentifiedDevelopers, anywhere.",
          "passwordPreviousPasswordBlockCount": "Number of previous passwords to block. Valid values 1 to 24.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "osMinimumBuildVersion": "Minimum MacOS build version.",
          "passwordExpirationDays": "Number of days before the password expires. Valid values 1 to 65535.",
          "firewallEnabled": "Whether the firewall should be enabled or not.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passwordMinimumCharacterSetCount": "The number of character sets required in the password.",
          "storageRequireEncryption": "Require encryption on Mac OS devices.",
          "osMaximumBuildVersion": "Maximum MacOS build version.",
          "firewallBlockAllIncoming": "Corresponds to the Block all incoming connections option.",
          "advancedThreatProtectionRequiredSecurityLevel": "MDATP Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "firewallEnableStealthMode": "Corresponds to Enable stealth mode.",
          "passwordMinimumLength": "Minimum length of password. Valid values 4 to 14.",
          "passwordRequiredType": "The required password type. Possible values are: deviceDefault, alphanumeric, numeric."
        },
        "#microsoft.graph.windows10MobileCompliancePolicy": {
          "passwordRequireToUnlockFromIdle": "Require a password to unlock an idle device.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passwordRequired": "Require a password to unlock Windows Phone device.",
          "activeFirewallRequired": "Require active firewall on Windows devices.",
          "validOperatingSystemBuildRanges": " The valid operating system build ranges on Windows devices. This collection can contain a maximum of 10000 elements.",
          "osMinimumVersion": "Minimum Windows Phone version.",
          "passwordMinimumCharacterSetCount": "The number of character sets required in the password.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "earlyLaunchAntiMalwareDriverEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation - early launch antimalware driver is enabled.",
          "passwordPreviousPasswordBlockCount": "The number of previous passwords to prevent re-use of.",
          "bitLockerEnabled": "Require devices to be reported healthy by Windows Device Health Attestation - bit locker is enabled",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16",
          "passwordRequiredType": "The required password type. Possible values are: deviceDefault, alphanumeric, numeric.",
          "secureBootEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation - secure boot is enabled.",
          "osMaximumVersion": "Maximum Windows Phone version.",
          "codeIntegrityEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation.",
          "storageRequireEncryption": "Require encryption on windows devices.",
          "passwordExpirationDays": "Number of days before password expiration. Valid values 1 to 255",
          "passwordBlockSimple": " Whether or not to block syncing the calendar.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required."
        },
        "#microsoft.graph.androidDeviceOwnerCompliancePolicy": {
          "securityRequireSafetyNetAttestationBasicIntegrity": "Require the device to pass the SafetyNet basic integrity check.",
          "osMinimumVersion": "Minimum Android version.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "osMaximumVersion": "Maximum Android version.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "passwordRequiredType": "Type of characters in password. Possible values are: deviceDefault, required, numeric, numericComplex, alphabetic, alphanumeric, alphanumericWithSymbols, lowSecurityBiometric, customPassword.",
          "passwordMinimumSymbolCharacters": "Indicates the minimum number of symbol characters required for device password. Valid values 1 to 16.",
          "passwordMinimumNumericCharacters": "Indicates the minimum number of numeric characters required for device password. Valid values 1 to 16.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "minAndroidSecurityPatchLevel": "Minimum Android security patch level.",
          "storageRequireEncryption": "Require encryption on Android devices.",
          "passwordMinimumLetterCharacters": "Indicates the minimum number of letter characters required for device password. Valid values 1 to 16.",
          "passwordExpirationDays": "Number of days before the password expires. Valid values 1 to 365.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passwordMinimumNonLetterCharacters": "Indicates the minimum number of non-letter characters required for device password. Valid values 1 to 16.",
          "securityRequireSafetyNetAttestationCertifiedDevice": "Require the device to pass the SafetyNet certified device check.",
          "passwordMinimumLowerCaseCharacters": "Indicates the minimum number of lower case characters required for device password. Valid values 1 to 16.",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "securityRequireIntuneAppIntegrity": "If setting is set to true, checks that the Intune app installed on fully managed, dedicated, or corporate-owned work profile Android Enterprise enrolled devices, is the one provided by Microsoft from the Managed Google Playstore. If the check fails, the device will be reported as non-compliant.",
          "advancedThreatProtectionRequiredSecurityLevel": "MDATP Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "passwordMinimumUpperCaseCharacters": "Indicates the minimum number of upper case letter characters required for device password. Valid values 1 to 16.",
          "passwordPreviousPasswordCountToBlock": "Number of previous passwords to block. Valid values 1 to 24.",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16.",
          "passwordRequired": "Require a password to unlock device."
        },
        "#microsoft.graph.defaultDeviceCompliancePolicy": {
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)"
        },
        "#microsoft.graph.windows10CompliancePolicy": {
          "passwordExpirationDays": "The password expiration in days.",
          "validOperatingSystemBuildRanges": "The valid operating system build ranges on Windows devices. This collection can contain a maximum of 10000 elements.",
          "bitLockerEnabled": "Require devices to be reported healthy by Windows Device Health Attestation - bit locker is enabled.",
          "rtpEnabled": "Require Windows Defender Antimalware Real-Time Protection on Windows devices.",
          "requireHealthyDeviceReport": "Require devices to be reported as healthy by Windows Device Health Attestation.",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Device Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "passwordBlockSimple": "Indicates whether or not to block simple password.",
          "defenderEnabled": "Require Windows Defender Antimalware on Windows devices.",
          "mobileOsMinimumVersion": "Minimum Windows Phone version.",
          "passwordMinimumCharacterSetCount": "The number of character sets required in the password.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "defenderVersion": "Require Windows Defender Antimalware minimum version on Windows devices.",
          "tpmRequired": "Require Trusted Platform Module(TPM) to be present.",
          "passwordRequiredType": "The required password type. Possible values are: deviceDefault, alphanumeric', numeric.",
          "mobileOsMaximumVersion": "Maximum Windows Phone version.",
          "antiSpywareRequired": "Require any AntiSpyware solution registered with Windows Decurity Center to be on and monitoring (e.g. Symantec, Windows Defender).",
          "osMinimumVersion": "Minimum Windows 10 version.",
          "passwordRequiredToUnlockFromIdle": "Require a password to unlock an idle device.",
          "storageRequireEncryption": "Require encryption on windows devices.",
          "passwordPreviousPasswordBlockCount": "The number of previous passwords to prevent re-use of.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from deviceCompliancePolicy",
          "passwordMinimumLength": "The minimum password length.",
          "antivirusRequired": "Require any Antivirus solution registered with Windows Decurity Center to be on and monitoring (e.g. Symantec, Windows Defender).",
          "secureBootEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation - secure boot is enabled.",
          "description": "Admin provided description of the Device Configuration. Inherited from deviceCompliancePolicy",
          "signatureOutOfDate": "Require Windows Defender Antimalware Signature to be up to date on Windows devices.",
          "activeFirewallRequired": "Require active firewall on Windows devices.",
          "codeIntegrityEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation.",
          "configurationManagerComplianceRequired": "Require to consider SCCM Compliance state into consideration for Intune Compliance State.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "earlyLaunchAntiMalwareDriverEnabled": "Require devices to be reported as healthy by Windows Device Health Attestation - early launch antimalware driver is enabled.",
          "deviceCompliancePolicyScript": "Not yet documented.",
          "osMaximumVersion": "Maximum Windows 10 version.",
          "passwordRequired": "Require a password to unlock Windows device."
        },
        "#microsoft.graph.androidWorkProfileCompliancePolicy": {
          "passwordRequired": "Require a password to unlock device.",
          "osMinimumVersion": "Minimum Android version.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "osMaximumVersion": "Maximum Android version.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "securityRequiredAndroidSafetyNetEvaluationType": "Require a specific SafetyNet evaluation type for compliance. Possible values are: basic, hardwareBacked.",
          "passwordPreviousPasswordBlockCount": "Number of previous passwords to block. Valid values 1 to 24",
          "requiredPasswordComplexity": "Indicates the required device password complexity on Android. One of: NONE, LOW, MEDIUM, HIGH. This is a new API targeted to Android API 12+. Possible values are: none, low, medium, high.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "minAndroidSecurityPatchLevel": "Minimum Android security patch level.",
          "securityRequireSafetyNetAttestationBasicIntegrity": "Require the device to pass the SafetyNet basic integrity check.",
          "passwordSignInFailureCountBeforeFactoryReset": "Number of sign-in failures allowed before factory reset. Valid values 1 to 16",
          "passwordExpirationDays": "Number of days before the password expires. Valid values 1 to 365",
          "securityRequireVerifyApps": "Require the Android Verify apps feature is turned on.",
          "securityPreventInstallAppsFromUnknownSources": "Require that devices disallow installation of apps from unknown sources.",
          "securityRequireUpToDateSecurityProviders": "Require the device to have up to date security providers. The device will require Google Play Services to be enabled and up to date.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "advancedThreatProtectionRequiredSecurityLevel": "MDATP Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "securityBlockJailbrokenDevices": "Devices must not be jailbroken or rooted.",
          "securityRequireCompanyPortalAppIntegrity": "Require the device to pass the Company Portal client app runtime integrity check.",
          "storageRequireEncryption": "Require encryption on Android devices.",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "securityRequireSafetyNetAttestationCertifiedDevice": "Require the device to pass the SafetyNet certified device check.",
          "securityDisableUsbDebugging": "Disable USB debugging on Android devices.",
          "securityRequireGooglePlayServices": "Require Google Play Services to be installed and enabled on the device.",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16",
          "passwordRequiredType": "Type of characters in password. Possible values are: deviceDefault, alphabetic, alphanumeric, alphanumericWithSymbols, lowSecurityBiometric, numeric, numericComplex, any."
        },
        "#microsoft.graph.iosCompliancePolicy": {
          "osMinimumVersion": "Minimum IOS version.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "osMaximumVersion": "Maximum IOS version.",
          "passcodeRequiredType": "The required passcode type. Possible values are: deviceDefault, alphanumeric, numeric.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "securityBlockJailbrokenDevices": "Devices must not be jailbroken or rooted.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passcodeBlockSimple": "Indicates whether or not to block simple passcodes.",
          "passcodeMinutesOfInactivityBeforeLock": "Minutes of inactivity before a passcode is required.",
          "passcodeMinutesOfInactivityBeforeScreenTimeout": "Minutes of inactivity before the screen times out.",
          "managedEmailProfileRequired": "Indicates whether or not to require a managed email profile.",
          "passcodePreviousPasscodeBlockCount": "Number of previous passcodes to block. Valid values 1 to 24.",
          "osMaximumBuildVersion": "Maximum IOS build version.",
          "passcodeExpirationDays": "Number of days before the passcode expires. Valid values 1 to 65535.",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "passcodeMinimumLength": "Minimum length of passcode. Valid values 4 to 14.",
          "passcodeRequired": "Indicates whether or not to require a passcode.",
          "osMinimumBuildVersion": "Minimum IOS build version.",
          "advancedThreatProtectionRequiredSecurityLevel": "MDATP Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "passcodeMinimumCharacterSetCount": "The number of character sets required in the password.",
          "restrictedApps": "Require the device to not have the specified apps installed. This collection can contain a maximum of 100 elements."
        },
        "#microsoft.graph.androidCompliancePolicy": {
          "conditionStatementId": "Condition statement id.",
          "securityRequireSafetyNetAttestationBasicIntegrity": "Require the device to pass the SafetyNet basic integrity check.",
          "passwordRequiredType": "Type of characters in password. Possible values are: deviceDefault, alphabetic, alphanumeric, alphanumericWithSymbols, lowSecurityBiometric, numeric, numericComplex, any.",
          "securityPreventInstallAppsFromUnknownSources": "Require that devices disallow installation of apps from unknown sources.",
          "storageRequireEncryption": "Require encryption on Android devices.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "osMaximumVersion": "Maximum Android version.",
          "osMinimumVersion": "Minimum Android version.",
          "securityRequireGooglePlayServices": "Require Google Play Services to be installed and enabled on the device.",
          "securityRequireVerifyApps": "Require the Android Verify apps feature is turned on.",
          "securityBlockJailbrokenDevices": "Devices must not be jailbroken or rooted.",
          "advancedThreatProtectionRequiredSecurityLevel": "MDATP Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "securityRequireCompanyPortalAppIntegrity": "Require the device to pass the Company Portal client app runtime integrity check.",
          "passwordRequired": "Require a password to unlock device.",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16",
          "passwordSignInFailureCountBeforeFactoryReset": "Number of sign-in failures allowed before factory reset. Valid values 1 to 16.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "securityRequireUpToDateSecurityProviders": "Require the device to have up to date security providers. The device will require Google Play Services to be enabled and up to date.",
          "requiredPasswordComplexity": "Indicates the required password complexity on Android. One of: NONE, LOW, MEDIUM, HIGH. This is a new API targeted to Android 11+. Possible values are: none, low, medium, high.",
          "securityDisableUsbDebugging": "Disable USB debugging on Android devices.",
          "passwordExpirationDays": "Number of days before the password expires. Valid values 1 to 365.",
          "passwordPreviousPasswordBlockCount": "Number of previous passwords to block. Valid values 1 to 24.",
          "minAndroidSecurityPatchLevel": "Minimum Android security patch level.",
          "securityRequireSafetyNetAttestationCertifiedDevice": "Require the device to pass the SafetyNet certified device check.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "securityBlockDeviceAdministratorManagedDevices": "Block device administrator managed devices.",
          "restrictedApps": "Require the device to not have the specified apps installed. This collection can contain a maximum of 100 elements."
        },
        "#microsoft.graph.androidForWorkCompliancePolicy": {
          "passwordRequired": "Require a password to unlock device.",
          "osMinimumVersion": "Minimum Android version.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "osMaximumVersion": "Maximum Android version.",
          "deviceThreatProtectionEnabled": "Require that devices have enabled device threat protection.",
          "passwordPreviousPasswordBlockCount": "Number of previous passwords to block. Valid values 1 to 24.",
          "requiredPasswordComplexity": "Indicates the required device password complexity on Android. One of: NONE, LOW, MEDIUM, HIGH. This is a new API targeted to Android API 12+. Possible values are: none, low, medium, high.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "minAndroidSecurityPatchLevel": "Minimum Android security patch level.",
          "securityRequireSafetyNetAttestationBasicIntegrity": "Require the device to pass the SafetyNet basic integrity check.",
          "passwordSignInFailureCountBeforeFactoryReset": "Number of sign-in failures allowed before factory reset. Valid values 1 to 16.",
          "passwordExpirationDays": "Number of days before the password expires. Valid values 1 to 365.",
          "securityRequireVerifyApps": "Require the Android Verify apps feature is turned on.",
          "securityPreventInstallAppsFromUnknownSources": "Require that devices disallow installation of apps from unknown sources.",
          "securityRequireUpToDateSecurityProviders": "Require the device to have up to date security providers. The device will require Google Play Services to be enabled and up to date.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "securityBlockJailbrokenDevices": "Devices must not be jailbroken or rooted.",
          "securityRequireSafetyNetAttestationCertifiedDevice": "Require the device to pass the SafetyNet certified device check.",
          "securityRequireCompanyPortalAppIntegrity": "Require the device to pass the Company Portal client app runtime integrity check.",
          "storageRequireEncryption": "Require encryption on Android devices.",
          "deviceThreatProtectionRequiredSecurityLevel": "Require Mobile Threat Protection minimum risk level to report noncompliance. Possible values are: unavailable, secured, low, medium, high, notSet.",
          "securityRequiredAndroidSafetyNetEvaluationType": "Require a specific SafetyNet evaluation type for compliance. Possible values are: basic, hardwareBacked.",
          "securityDisableUsbDebugging": "Disable USB debugging on Android devices.",
          "securityRequireGooglePlayServices": "Require Google Play Services to be installed and enabled on the device.",
          "passwordMinimumLength": "Minimum password length. Valid values 4 to 16.",
          "passwordRequiredType": "Type of characters in password. Possible values are: deviceDefault, alphabetic, alphanumeric, alphanumericWithSymbols, lowSecurityBiometric, numeric, numericComplex, any."
        },
        "#microsoft.graph.windows81CompliancePolicy": {
          "passwordExpirationDays": "Password expiration in days.",
          "passwordRequiredType": "The required password type. Possible values are: deviceDefault, alphanumeric, numeric.",
          "passwordMinimumLength": "The minimum password length.",
          "passwordPreviousPasswordBlockCount": "The number of previous passwords to prevent re-use of. Valid values 0 to 24.",
          "passwordMinimumCharacterSetCount": "The number of character sets required in the password.",
          "storageRequireEncryption": "Indicates whether or not to require encryption on a windows 8.1 device.",
          "osMinimumVersion": "Minimum Windows 8.1 version.",
          "description": "Admin provided description of the Device Configuration. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passwordRequired": "Require a password to unlock Windows device.",
          "passwordMinutesOfInactivityBeforeLock": "Minutes of inactivity before a password is required.",
          "osMaximumVersion": "Maximum Windows 8.1 version.",
          "roleScopeTagIds": "List of Scope Tags for this Entity instance. Inherited from [deviceCompliancePolicy](../resources/intune-shared-devicecompliancepolicy.md)",
          "passwordBlockSimple": "Indicates whether or not to block simple password."
        }
      }          
'@
    # convert the JSON to a Hash
    $propHash = ConvertFrom-Json -InputObject $propHashJSON

    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    # go thru every property (key) of the policy
    foreach ($key in $policy.keys) { 
        # check if the property exists (not null) and is not one of the following types, bc they r selfexplanatory and we dont need the description
        if (($null -ne $policy.$key) -and ($key -notin ("@odata.type", "id", "createdDateTime", "lastModifiedDateTime", "displayName", "version"))) {
            # check if the property exists in the nested Hash
            if ($null -ne $policy.$key) {
                # save the @odata.type to use as key1 of the Hash
                $odataType = $policy.'@odata.type'
                #print the setting(property name) | its' value | Description as stored in key2 of the Hash
                "|$key|$($policy.$key)|$($propHash.$odataType.$key)|"         #work ffs! Edit: It WORKS!
            }
            # check if the property is not in the hash  and print description as "Not documented yet."
            elseif ($null -eq $propHash.$policy.$key) {
                "|$key|$($policy.$key)|Not documented yet.|"
            }
        }
    }
    ""

    # "#### Assignments"
    # get the policy's assignments
    $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)/assignments"

    ConvertToMarkdown-PolicyAssignments -assignments $assignments
}

function ConvertToMarkdown-ConditionalAccessPolicy {
    param(
        $policy
    )

    "### $($policy.displayName)"
    ""
    "|Setting|Value|"
    "|-------|-----|"
    "|State|$($policy.state)|"
    ""

    "#### Conditions"
    ""
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    if ($policy.conditions.applications.includeApplications) {
        "|Include applications|$(foreach ($app in $policy.conditions.applications.includeApplications) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.excludeApplications) {
        "|Exclude applications|$(foreach ($app in $policy.conditions.applications.excludeApplications) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.includeUserActions) {
        "|Include user actions|$(foreach ($app in $policy.conditions.applications.includeUserActions) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.excludeUserActions) {
        "|Exclude user actions|$(foreach ($app in $policy.conditions.applications.excludeUserActions) { $app + "<br/>"})||"
    }
    if ($policy.conditions.platforms.includePlatforms) {
        "|Include platforms|$(foreach ($platform in $policy.conditions.platforms.includePlatforms) { $platform + "<br/>"})||"
    }
    if ($policy.conditions.platforms.excludePlatforms) {
        "|Exclude platforms|$(foreach ($platform in $policy.conditions.platforms.excludePlatforms) { $platform + "<br/>"})||"
    }
    if ($policy.conditions.locations.includeLocations) {
        "|Include locations|$(foreach ($location in $policy.conditions.locations.includeLocations) { $location + "<br/>"})||"
    }
    if ($policy.conditions.locations.excludeLocations) {
        "|Exclude locations|$(foreach ($location in $policy.conditions.locations.excludeLocations) { $location + "<br/>"})||"
    }
    if ($policy.conditions.users.includeGroups) {
        "|Include groups|$(foreach ($group in $policy.conditions.users.includeGroups) { $group + "<br/>"})||"
    }
    if ($policy.conditions.users.excludeGroups) {
        "|Exclude groups|$(foreach ($group in $policy.conditions.users.excludeGroups) { $group + "<br/>"})||"
    }
    if ($policy.conditions.users.includeRoles) {
        "|Include roles|$(foreach ($role in $policy.conditions.users.includeRoles) { $role + "<br/>"})||"
    }  
    if ($policy.conditions.users.excludeRoles) {
        "|Exclude roles|$(foreach ($role in $policy.conditions.users.excludeRoles) { $role + "<br/>"})||"
    }  
    if ($policy.conditions.users.includeUsers) {
        "|Include users|$(foreach ($user in $policy.conditions.users.includeUsers) { $user + "<br/>"})||"
    }
    if ($policy.conditions.users.excludeUsers) {
        "|Exclude users|$(foreach ($user in $policy.conditions.users.excludeUsers) { $user + "<br/>"})||"
    }
    if ($policy.conditions.clientAppTypes) {
        "|Client app types|$(foreach ($app in $policy.conditions.clientAppTypes) { $app + "<br/>"})||"
    }
    if ($policy.conditions.servicePrincipalRiskLevels) {
        "|Service principal risk levels|$(foreach ($risklevel in $policy.conditions.servicePrincipalRiskLevels) { $risklevel + "<br/>"})||"
    }
    if ($policy.conditions.signInRiskLevels) {
        "|Sign-in risk levels|$(foreach ($risklevel in $policy.conditions.signInRiskLevels) { $risklevel + "<br/>"})||"
    }
    if ($policy.conditions.userRiskLevels) {
        "|User risk levels|$(foreach ($risklevel in $policy.conditions.userRiskLevels) { $risklevel + "<br/>"})||"
    }
    if ($policy.conditions.deviceStates.includeStates) {
        "|Include device states|$(foreach ($state in $policy.conditions.deviceStates.includeStates) { $state + "<br/>"})||"
    }
    if ($policy.conditions.deviceStates.excludeStates) {
        "|Exclude device states|$(foreach ($state in $policy.conditions.deviceStates.excludeStates) { $state + "<br/>"})||"
    }
    if ($policy.conditions.devices.includeDevices) {
        "|Include devices|$(foreach ($device in $policy.conditions.devices.includeDevices) { $device + "<br/>"})||"
    }
    if ($policy.conditions.devices.excludeDevices) {
        "|Exclude devices|$(foreach ($device in $policy.conditions.devices.excludeDevices) { $device + "<br/>"})||"
    }
    if ($policy.conditions.devices.deviceFilter) {
        foreach ($filter in $policy.conditions.devices.deviceFilter) {
            "|Device filter|Mode: $($filter.mode)<br/>Rule: $($filter.rule)||"
        }
    }
    ""

    "#### Grant controls"
    ""
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    if ($policy.grantControls.operator) {
        "|Operator|$($policy.grantControls.operator)||"
    }
    if ($policy.grantControls.builtInControls) {
        "|Built-in controls|$(foreach ($control in $policy.grantControls.builtInControls) { $control + "<br/>"})||"
    }
    if ($policy.grantControls.customAuthenticationFactors) {
        "|Custom authentication factors|$(foreach ($factor in $policy.grantControls.customAuthenticationFactors) { $factor + "<br/>"})||"
    }
    if ($policy.grantControls.termsOfUse) {
        "|Terms of use|$(foreach ($term in $policy.grantControls.termsOfUse) { $term + "<br/>"})||"
    }
    if ($policy.grantControls.authenticationStrength) {
        foreach ($strength in $policy.grantControls.authenticationStrength) {
            "|Authentication strength: $($strength.displayName)|Allowed combinations:<br/>$(foreach ($combination in $strength.allowedCombinations) {$combination + "<br/>"})|$($strength.description)|"
        }
    }
    ""

    "#### Session controls"
    ""
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    if ($policy.sessionControls.applicationEnforcedRestrictions.isEnabled) {
        "|Session control enabled|$True||"
    }	
    if ($policy.sessionControls.cloudAppSecurity) {
        foreach ($app in $policy.sessionControls.cloudAppSecurity) {
            "|Cloud app securit is enabled|$($app.isEnabled)||"
            "|Cloud app security type|$($app.cloudAppSecurityType)||"
        }
    }	
    if ($policy.sessionControls.signinFrequency.isEnabled) {
        "|Sign-in frequency enabled|$($policy.sessionControls.signinFrequency.isEnabled)||"	
    }
    if ($policy.sessionControls.signinFrequency.frequencyInterval) {
        "|Sign-in frequency interval|$($policy.sessionControls.signinFrequency.frequencyInterval)|Enforce reauth every time, or only after a certain time|"
    }
    if ($policy.sessionControls.signinFrequency.value) {
        "|Sign-in frequency interval value|$($policy.sessionControls.signinFrequency.value)|Amount of time between reauthentications|"
    }
    if ($policy.sessionControls.signinFrequency.type) {
        "|Sign-in frequency interval type|$($policy.sessionControls.signinFrequency.type)|Days or Hours|"
    }
    if ($policy.sessionControls.signinFrequency.authenticationType) {
        "|Sign-in frequency authentication type|$($policy.sessionControls.signinFrequency.authenticationType)|Which kind of auth. to inforce after interval passes|"
    }
    if ($policy.sessionControls.persistentBrowser.isEnabled) {
        "|Persistent browser enabled|$($policy.sessionControls.persistentBrowser.isEnabled)||"
    }
    if ($policy.sessionControls.persistentBrowser.mode) {
        "|Persistent browser mode|$($policy.sessionControls.persistentBrowser.mode)|Allow or Deny persistent browser sessions|"
    }
    if ($policy.sessionControls.disableResilienceDefaults) {
        "|Disable resilience defaults|$($policy.sessionControls.disableResilienceDefaults)||"
    }

}

function ConvertToMarkdown-ConfigurationPolicy {
    # Still missing
    # - assignments

    param(
        $policy
    )

    "### $($policy.name)"
    "$($policy.description)"
    ""
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    $settings = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings`?`$expand=settingDefinitions`&top=1000"
    foreach ($setting in $settings.value) {

        if ($setting.settingInstance."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
            $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $setting.settingInstance.settingDefinitionId }
            $displayValue = ($definition.options | Where-Object { $_.itemId -eq $setting.settingInstance.choiceSettingValue.value }).displayName
            $setting.settingInstance.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                $displayValue += "<br/>$_"
            }
            "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
        }
        elseif ($setting.settingInstance."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance") {
            foreach ($groupSetting in $setting.settingInstance.groupSettingCollectionValue.children) {
                if ($groupSetting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
                    $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $groupSetting.settingDefinitionId }
                    $displayValue = ($definition.options | Where-Object { $_.itemId -eq $groupSetting.choiceSettingValue.value }).displayName
                    $groupSetting.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                        $displayValue += "<br/>$_"
                    }
                    "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
                }

                if ($groupSetting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance") {
                    foreach ($group2Setting in $groupSetting.groupSettingCollectionValue.children) {
                        $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $group2Setting.settingDefinitionId }
                        if ($group2Setting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
                            $displayValue = ($definition.options | Where-Object { $_.itemId -eq $group2Setting.choiceSettingValue.value }).displayName
                            $group2Setting.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                                $displayValue += "<br/>$_"
                            }
                            "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
                        }
                        elseif ($group2Setting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance") {
                            #"TYPE: DEBUG: Choice Setting Collection"
                            "|$($definition.displayName)|$(
                            foreach ($value in $group2Setting.choiceSettingCollectionValue.value) {
                                ($definition.options | Where-Object { $_.itemId -eq $value }).displayName
                            }
                            )|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
                        }
                        else {
                            "| TYPE: $($group2Setting."@odata.type") not yet supported ||"
                        }
                    }
                }
            }
        }
        else {
            "| TYPE: $($setting.settingInstance."@odata.type") not yet supported ||"
        }
    }
    ""

    # "#### Assignments"
    # get the policy's assignments
    $assignments = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/assignments"

    ConvertToMarkdown-PolicyAssignments -assignments $assignments
}

function ConvertToMarkdown-DeviceConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        $policy
    )

    "### $($policy.displayName)" 
    ""

    "| Setting | Value | Description |"
    "| ------- | ----- | ----------- |"
    foreach ($key in $policy.keys) {
        if ($key -notin @("id", "displayName", "version", "lastModifiedDateTime", "createdDateTime", "@odata.type")) {
            if ($null -ne $policy.$key) {
                "| $($key) | $(foreach ($value in $policy.$key) { 
                        if (($value -is [System.Collections.Hashtable]))
                        {
                            # Handle encryption of SiteToZone Assignments
                            if ($value.omaUri -eq "./User/Vendor/MSFT/Policy/Config/InternetExplorer/AllowSiteToZoneAssignmentList") {
                                $decryptedValue = invoke-mggraphrequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($value.secretReferenceValueId)')"
                                $decryptedValue = ($decryptedValue.value.split('"')[3]) -replace '&#xF000;',';'
                                "displayName : $($value.displayName)<br/>"
                                [array]$pairs = $decryptedValue.Split(';')
                                if (($pairs.Count % 2) -eq 0) {
                                    [int]$i = 0;
                                    do {
                                        switch ($pairs[$i + 1]) {
                                            0 { $value = "My Computer (0)" }
                                            1 { $value = "Local Intranet Zone (1)" }
                                            2 { $value = "Trusted sites Zone (2)" }
                                            3 { $value = "Internet Zone (3)" }
                                            4 { $value = "Restricted Sites Zone (4)" }
                                            Default { $value = $pairs[$i + 1] }
                                        }
                                        "$($pairs[$i]) : $value<br/>"
                                        $i = $i + 2
                                    } while ($i -lt $pairs.Count)
                                } else {
                                    "Error in parsing SiteToZone Assignments"
                                }
                            } else { 
                            foreach ($subkey in $value.keys) {
                                if ($null -ne $value.$subkey) {
                                    if ($value.$subkey.length -gt 200) {
                                        "$subkey : $($value.$subkey.Substring(0,199))...<br/>"
                                    } else {
                                        "$subkey : $($value.$subkey)<br/>"
                                    }
                                }
                            }  
                        }
                        }
                        else
                        {
                            if ($value.length -gt 200) {
                                "$($value.Substring(0,199))...<br/>"
                            } else {
                                "$value<br/>" 
                            }
                        }
                    }) | |"
            }
            
        }
    }
    ""

    # "#### Assignments"
    # get the policy's assignments
    $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/assignments"

    ConvertToMarkdown-PolicyAssignments -assignments $assignments
}

function ConvertToMarkdown-GroupPolicyConfiguration {
    param(
        $policy
    )

    # Process the policy and its definitions like https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/a53d6338-37b3-4964-b732-16cb68eb3a21/definitionValues/dacb5076-5625-4a6f-b93b-3906c3e113eb/definition
    # to create a table with the settings and their values
    #
    # Maybe "https://graph.microsoft.com/beta/deviceManagement/groupPolicyCategories?$expand=parent($select=id,displayName,isRoot),definitions($select=id,displayName,categoryPath,classType,policyType,version,hasRelatedDefinitions)&$select=id,displayName,isRoot,ingestionSource&$filter=ingestionSource eq 'builtIn'" helps

    "### $($policy.displayName)"
    ""
    if ($policy.description) {
        "$($policy.description)"
        ""
    }

    $definitionValues = (Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues").value
    $definitionValues | ForEach-Object {
        $definitionValue = $_
        $definition = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/definition"
        "#### $($definition.displayName)"
        ""
        #"$($definition.explainText)"
        #""
        "|Setting|Value|Description|"
        "|---|---|---|"
        # replace newlines in $($definition.explainText) with `<br/>` to get a proper markdown table
        "| Enabled | $($_.enabled) | $($definition.explainText.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>") |"
        $presentationValues = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/presentationValues"
        foreach ($presentationValue in $presentationValues.value) {
            $presentation = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/presentationValues/$($presentationValue.id)/presentation"
            # "Label: " + $($presentation.label)
            $item = ($presentation.items | Where-Object { $_.value -eq $presentationValue.value })
            if ($item) {
                "| $($presentation.label) | $($item.displayName) ||"
                #"Value: " + $($item.displayName)
            }
            else {
                "| $($presentation.label) | $($presentationValue.value) ||"
                #"Value: " + $($presentationValue.value)
            }
        }
        ""
    }

    # "#### Assignments"
    # get the policy's assignments
    $assignments = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/assignments"

    ConvertToMarkdown-PolicyAssignments -assignments $assignments
}

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Sanity checks
if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore:"
    "## - TenantPolicyReport.ResourceGroup"
    "## - TenantPolicyReport.StorageAccount.Name"
    "## - TenantPolicyReport.StorageAccount.Location"
    "## - TenantPolicyReport.StorageAccount.Sku"
    ""
    "## Disabling CSV export..."
    $exportToFile = $false
    ""
}

"## Authenticating to Microsoft Graph..."

# Temporary file for markdown output
$outputFileMarkdown = "$env:TEMP\$(get-date -Format "yyyy-MM-dd")-policy-report.md"

## Auth (directly calling auth endpoint)
$resourceURL = "https://graph.microsoft.com/" 
$authUri = $env:IDENTITY_ENDPOINT
$headers = @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"}

$AuthResponse = Invoke-WebRequest -UseBasicParsing -Uri "$($authUri)?resource=$($resourceURL)" -Method 'GET' -Headers $headers
$accessToken = ($AuthResponse.content | ConvertFrom-Json).access_token

#Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All,Policy.Read.All"

"## Connecting to Microsoft Graph..."

try {
Connect-MgGraph -AccessToken $accessToken | Out-Null
} catch {
    "## Error connecting to Microsoft Graph."
    ""
    "## Probably: Managed Identity is not configured."
    throw("Auth failed")
}

""
"## Creating Report..."

if ($exportJson) {
    mkdir "$($env:TEMP)\json-export" | Out-Null
}

# Header
"# Report" > $outputFileMarkdown
"" >> $outputFileMarkdown

#region Configuration Policy (Settings Catalog, Endpoint Sec.)
"## - Configuration Policies (Settings Catalog)"
"## Configuration Policies (Settings Catalog)" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$policies = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies`?`$top=1000" 

foreach ($policy in $policies.value) {
    if ($exportJson) {
        $policy | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-confPol-$($policy.id).json" -Encoding UTF8 
        $settings = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings`?`$expand=settingDefinitions`&top=1000"
        $settings | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-confPol-$($policy.id)-settings.json" -Encoding UTF8
        $assignments = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/assignments"	
        $assignments | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-confPol-$($policy.id)-assignments.json" -Encoding UTF8
    }
    (ConvertToMarkdown-ConfigurationPolicy -policy $policy).replace('\','\\') >> $outputFileMarkdown    
    "" >> $outputFileMarkdown
}
#endregion

#region Device Configurations
"## - Device Configurations"
"## Device Configurations" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$deviceConfigurations = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations`?`$top=1000"

foreach ($policy in $deviceConfigurations.value) {
    if ($exportJson) {
        $policy | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-devConf-$($policy.id).json" -Encoding UTF8 
        $assignments = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/assignments"	
        $assignments | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-devConf-$($policy.id)-assignments.json" -Encoding UTF8
    }
    ConvertToMarkdown-DeviceConfiguration -policy $policy >> $outputFileMarkdown
    "" >> $outputFileMarkdown
}
#endregion

#region Group Policy Configurations
"## - Group Policy Configurations"
"## Group Policy Configurations" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$groupPolicyConfigurations = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations`?`$top=1000"

foreach ($policy in $groupPolicyConfigurations.value) {
    if ($exportJson) {
        $policy | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-grpPol-$($policy.id).json" -Encoding UTF8 
        $definitionValues = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues?`$expand=definition,presentationValues"
        $definitionValues | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-grpPol-$($policy.id)-definitionValues.json" -Encoding UTF8
        $assignments = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/assignments"	
        $assignments | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-grpPol-$($policy.id)-assignments.json" -Encoding UTF8
    }
    ConvertToMarkdown-GroupPolicyConfiguration -policy $policy >> $outputFileMarkdown
    "" >> $outputFileMarkdown
}
#endregion

#region Compliance Policies
"## - Compliance Policies"
"## Compliance Policies" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$compliancePolicies = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies`?`$top=1000"

foreach ($policy in $compliancePolicies.value) {
    if ($exportJson) {
        $policy | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-comPol-$($policy.id).json" -Encoding UTF8 
        $assignments = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)/assignments"	
        $assignments | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-comPol-$($policy.id)-assignments.json" -Encoding UTF8
    }
    ConvertToMarkdown-CompliancePolicy -policy $policy >> $outputFileMarkdown
    "" >> $outputFileMarkdown
}
#endregion

#region Conditional Access Policies
"## - Conditional Access Policies"
"## Conditional Access Policies" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$conditionalAccessPolicies = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies`?`$top=1000"

foreach ($policy in $conditionalAccessPolicies.value) {
    if ($exportJson) {
        $policy | ConvertTo-Json -Depth 100 | Out-File -FilePath "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-condAcc-$($policy.id).json" -Encoding UTF8 
    }	
    ConvertToMarkdown-ConditionalAccessPolicy -policy $policy >> $outputFileMarkdown
    "" >> $outputFileMarkdown
}
#endregion

# Footer
"" >> $outputFileMarkdown
""

"## Uploading to Azure Storage Account..."

Connect-RjRbAzAccount

if (-not $ContainerName) {
    $ContainerName = "tenant-policy-report-" + (get-date -Format "yyyy-MM-dd")
}

# Make sure storage account exists
$storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not $storAccount) {
    "## Creating Azure Storage Account $($StorageAccountName)"
    $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku
}

# Get access to the Storage Account
$keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value

# Make sure, container exists
$container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
if (-not $container) {
    "## Creating Azure Storage Account Container $($ContainerName)"
    $container = New-AzStorageContainer -Name $ContainerName -Context $context 
}

$EndTime = (Get-Date).AddDays(6)

# Create a ZIP file of the JSON export
if ($exportJson) {
    "## Creating ZIP file of JSON export"
    $zipFile = "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-policy-report.zip"
    Compress-Archive -Path "$($env:TEMP)\json-export\*.json" -DestinationPath $zipFile
}

# Upload JSON archive
if ($exportJson) {
    $blobname = "$(get-date -Format "yyyy-MM-dd")-policy-report.zip"
    $blob = Set-AzStorageBlobContent -File "$($env:TEMP)\json-export\$(get-date -Format "yyyy-MM-dd")-policy-report.zip" -Container $ContainerName -Blob $blobname -Context $context -Force
    if ($produceLinks) {
        #Create signed (SAS) link
        $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobname -FullUri -ExpiryTime $EndTime
        "## Raw JSON export"
        " $SASLink"
        ""
    }
}

# Make sure Markdown is UTF8 and make sure Markdown contains no singular backslash
$content = Get-Content $outputFileMarkdown 
$content = $content -replace '([0-9a-zA-z])(\\+)([0-9a-zA-z])','$1\\$3'
$content = $content -replace '^| TYPE: #(.*) not yet supported ||$', ''
$content | Set-Content $outputFileMarkdown -Encoding UTF8

# Upload markdown file
$blobname = "$(get-date -Format "yyyy-MM-dd")-policy-report.md"
$blob = Set-AzStorageBlobContent -File $outputFileMarkdown -Container $ContainerName -Blob $blobname -Context $context -Force
if ($produceLinks) {
    #Create signed (SAS) link
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobname -FullUri -ExpiryTime $EndTime
    "## Markdown report"
    " $SASLink"
    ""
}

Disconnect-AzAccount | Out-Null
Disconnect-MgGraph | Out-Null
