<#
	.SYNOPSIS
	Update user metadata and memberships

	.DESCRIPTION
	Updates user profile properties in Microsoft Entra ID and applies optional group memberships and Exchange Online settings. This runbook is typically used to finalize onboarding or to correct user metadata.

	.PARAMETER UserName
	User principal name of the target user.

	.PARAMETER GivenName
	Given name to set for the user.

	.PARAMETER Surname
	Surname to set for the user.

	.PARAMETER DisplayName
	Display name to set for the user.

	.PARAMETER CompanyName
	Company name to set for the user.

	.PARAMETER City
	City to set for the user.

	.PARAMETER Country
	Country to set for the user.

	.PARAMETER JobTitle
	Job title to set for the user.

	.PARAMETER Department
	Department to set for the user.

	.PARAMETER OfficeLocation
	Office location to set for the user.

	.PARAMETER PostalCode
	Postal code to set for the user.

	.PARAMETER PreferredLanguage
	Preferred language to set for the user. Examples: "en-US" or "de-DE".

	.PARAMETER State
	State to set for the user.

	.PARAMETER StreetAddress
	Street address to set for the user.

	.PARAMETER UsageLocation
	Usage location to set for the user.

	.PARAMETER DefaultLicense
	Display name of a license group to assign.

	.PARAMETER DefaultGroups
	Comma-separated list of group display names to assign.

	.PARAMETER EnableEXOArchive
	If set to true, enables the Exchange Online archive mailbox.

	.PARAMETER ResetPassword
	If set to true, resets the user's password.

	.PARAMETER CallerName
	Caller name is tracked purely for auditing purposes.

    .EXAMPLE
    // Full Runbook Customizing Example
    "Templates": {
        "Options": [
            {
                "$id": "LocationOptions",
                "$values": [
                    {
                        "Display": "Contoso DE",
                        "Value": "ContosoDe",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Demostr. 22",
                                "PostalCode": "80333",
                                "City": "München",
                                "State": "Bayern",
                                "Country": "Germany",
                                "UsageLocation": "DE"
                            },
                            "ReadOnly": [
                                "StreetAddress",
                                "PostalCode",
                                "City",
                                "Country",
                                "UsageLocation"
                            ]
                        }
                    }
                ]
            },
            {
                "$id": "CompanyOptions",
                "$values": [
                    {
                        "Display": "CONTOSO",
                        "Value": "Contoso"
                    }
                ]
            },
            {
                "$id": "LicenseOptions",
                "$values": [
                    {
                        "Display": "M365 E3 + E5 Security + Audio Conferencing",
                        "Value": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
                    },
                    {
                        "Display": "none",
                        "Value": ""
                    }
                ]
            },
            {
                "$id": "DepartmentOptions",
                "$values": [
                    {
                        "Display": "M&A",
                        "Value": "M&A"
                    },
                    {
                        "Display": "Tax & Legal",
                        "Value": "Tax & Legal"
                    },
                    {
                        "Display": "Controlling & Operations",
                        "Value": "Controlling & Operations"
                    },
                    {
                        "Display": "IT",
                        "Value": "IT"
                    },
                    {
                        "Display": "Communications",
                        "Value": "Communications"
                    },
                    {
                        "Display": "Strategy & Management",
                        "Value": "Strategy & Management"
                    },
                    {
                        "Display": "Accounting",
                        "Value": "Accounting"
                    },
                    {
                        "Display": "Insurance",
                        "Value": "Insurance"
                    },
                    {
                        "Display": "Treasury",
                        "Value": "Treasury"
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-user_userinfo_update-user": {
            "ParameterList": [
                {
                    "Name": "LocationName",
                    "DisplayName": "Office Location",
                    "DisplayBefore": "StreetAddress",
                    "Select": {
                        "Options": {
                            "$ref": "LocationOptions"
                        }
                    },
                    "Default": "ContosoDe"
                },
                {
                    "Name": "CompanyName",
                    "Select": {
                        "Options": {
                            "$ref": "CompanyOptions"
                        },
                        "AllowEdit": false,
                    },
                    "Default": "Contoso"
                },
                {
                    "Name": "DefaultLicense",
                    "DisplayName": "License",
                    "Select": {
                        "Options": {
                            "$ref": "LicenseOptions"
                        },
                        "AllowEdit": true
                    },
                    "Default": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
                },
                {
                    "Name": "Department",
                    "Select": {
                        "Options": {
                            "$ref": "DepartmentOptions"
                        },
                        "AllowEdit": true
                    }
                },
                {
                    "Name": "ResetPassword",
                    "Hide": true
                },
                {
                    "Name": "DefaultGroups",
                    "Default": "app - 7-Zip,app - Adobe Reader DC Continuous Track,app - glueckkanja-gab KONNEKT"
                }
            ]
        }
    }

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			},
			"DisplayName": {
				"DisplayName": "DisplayName"
			},
			"DefaultLicense": {
				"DisplayName": "License group to assign"
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param (
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [string]$GivenName,
    [string]$Surname,
    [string]$DisplayName,
    [string]$CompanyName,
    [string]$City,
    [string]$Country,
    [string]$JobTitle,
    [string]$Department,
    # think "physicalDeliveryOfficeName" if you are coming from on-prem
    [string]$OfficeLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number } )]
    [string]$PostalCode,
    [string]$PreferredLanguage,
    [string]$State,
    [string]$StreetAddress,
    [string]$UsageLocation,
    [string]$DefaultLicense = "",
    [string]$DefaultGroups = "",
    [bool]$EnableEXOArchive = $false,
    [bool]$ResetPassword = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Updating metadata of user '$UserName'."

Connect-RjRbGraph
Connect-RjRbExchangeOnline

try {
    Write-RjRbLog "Searching for user '$UserName'"
    $targetUser = Invoke-RjRbRestMethodGraph -resource "/users/$UserName" -OdSelect "companyName,displayName,givenName,surname,mail,userPrincipalName,jobTitle,id,MailNickName"

    $userArgs = @{}
    function addToUserArgs($variableName, $paramName = $variableName) {
        $paramValue = Get-Variable $variableName -ValueOnly -EA 0
        if ($paramValue) {
            $userArgs[$paramName] = $paramValue
        }
    }
    addToUserArgs 'givenName'
    addToUserArgs 'surname'
    addToUserArgs 'displayName'
    addToUserArgs 'companyName'
    addToUserArgs 'city'
    addToUserArgs 'country'
    addToUserArgs 'jobTitle'
    addToUserArgs 'department'
    addToUserArgs 'officeLocation'
    addToUserArgs 'postalCode'
    addToUserArgs 'preferredLanguage'
    addToUserArgs 'state'
    addToUserArgs 'streetAddress'
    addToUserArgs 'usageLocation'

    if (-not $targetUser.DisplayName -and -not $DisplayName) {
        $resultingGivenName = if ($GivenName) { $GivenName } else { $targetUser.GivenName }
        $resultingSurname = if ($Surname) { $Surname } else { $targetUser.Surname }
        if ($resultingGivenName -and $resultingSurname) {
            $userArgs['displayName'] = "$resultingGivenName $resultingSurname"
        }
        else {
            $userArgs['displayName'] = $targetUser.MailNickName
        }
    }
    if (-not $targetUser.CompanyName -and -not $CompanyName) {
        $tenantDetail = Invoke-RjRbRestMethodGraph -Resource "/organization"
        $userArgs['companyName'] = $tenantDetail.displayName
    }

    Write-RjRbLog "Updating user object with the following properties" $userArgs
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $userArgs

    if ($DefaultLicense -ne "") {
        #"Searching license group $DefaultLicense."
        $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$DefaultLicense'" -OdSelect "displayName, assignedLicenses, id" -ErrorAction SilentlyContinue

        if (-not $group) {
            "## License group '$DefaultLicense' not found!"
            "## Reauth..."
            Connect-RjRbGraph -force
        }
        else {
            $members = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members" -FollowPaging
            if ($members.id -contains $targetUser.id) {
                "## License Group '$DefaultLicense' is already assigned tp '$Username'. Skipping."
            }
            else {
                $licenses = $group.assignedLicenses
                $enoughlicenses = $true
                foreach ($license in $licenses) {
                    $sku = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" | Where-Object { $_.skuID -eq $license.skuId }
                    $SkuRemaining = $sku.prepaidUnits.enabled - $sku.consumedUnits
                    if ($SkuRemaining -le 0) {
                        $enoughlicenses = $false
                    }
                }
                if ($enoughlicenses) {
                    "## Adding '$Username' to license group '$($group.displayName)'"
                    $body = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
                    }
                    try {
                        Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/`$ref" -Method Post -Body $body | Out-Null
                        #"## '$($group.displayName)' assigned to '$Username'"
                    }
                    catch {
                        "## ... failed. Skipping '$($group.displayName)'."
                        Write-RjRbLog $_
                        "## Reauth..."
                        Connect-RjRbGraph -force
                    }
                }
                else {
                    "## WARNING - Licensegroup '$DefaultLicense' lacks sufficient licenses! Not provisioning license / group membership."
                }
            }

        }
    }

    # Assign the given groups. Continue even if this fails.
    $groupsArray = $DefaultGroups.split(',').Trim()
    foreach ($groupname in $groupsArray) {
        if ($groupname -ne "") {
            #"Searching default group $groupname."
            $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$groupname'" -ErrorAction SilentlyContinue
            if (-not $group) {
                "## Group '$groupname' not found!"
                "## Reauth..."
                Connect-RjRbGraph -force
            }
            else {
                if (($group.GroupTypes -contains "Unified") -or (-not $group.MailEnabled)) {
                    $members = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members" -FollowPaging
                    if ($members.id -contains $targetUser.id) {
                        "## Group '$($group.displayName)' is already assigned tp '$Username'. Skipping."
                    }
                    else {
                        "## Adding '$Username' to group '$($group.displayName)'"
                        $body = @{
                            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
                        }
                        try {
                            Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/`$ref" -Method Post -Body $body | Out-Null
                        }
                        catch {
                            "## ... failed. Skipping '$($group.displayName)'."
                            Write-RjRbLog $_
                            "## Reauth..."
                            Connect-RjRbGraph -force
                        }
                    }
                }
                else {
                    try {
                        "## Adding to exchange group/list '$($group.displayName)'"
                        # Mailbox needs to be provisioned first. EXO takes multiple minutes to privision a fresh mailbox.
                        $mbox = get-exomailbox -Identity $Username -ErrorAction SilentlyContinue
                        if (-not $mbox) {
                            $MaxRuns = 30
                            "## - Waiting for Mailbox creation. Max Wait Time ca. $($MaxRuns/2) minutes."
                            $mbox = $null;
                            $counter = 0
                            while ((-not $mbox) -and ($counter -le $MaxRuns)) {
                                $counter++;
                                Start-Sleep 30;
                                $mbox = get-exomailbox -Identity $Username -ErrorAction SilentlyContinue;
                            };
                        }
                        Add-DistributionGroupMember -Identity $group.id -Member $Username -BypassSecurityGroupManagerCheck:$true -Confirm:$false
                    }
                    catch {
                        "## ... failed. Skipping '$($group.displayName)'."
                        Write-RjRbLog $_
                    }
                }
            }
        }
    }

    # Enable Exchange Online Archive
    if ($EnableEXOArchive) {
        try {
            "## Enabling EXO Archive Mailbox"
            # Mailbox needs to be provisioned first. EXO takes multiple minutes to privision a fresh mailbox.
            $mbox = get-exomailbox -Identity $Username -ErrorAction SilentlyContinue
            if (-not $mbox) {
                $MaxRuns = 30
                "## - Waiting for Mailbox creation. Max Wait Time ca. $($MaxRuns/2) minutes."
                $mbox = $null;
                $counter = 0
                while ((-not $mbox) -and ($counter -le $MaxRuns)) {
                    $counter++;
                    Start-Sleep 30;
                    $mbox = get-exomailbox -Identity $Username -ErrorAction SilentlyContinue;
                };
            }
            $archivembox = get-exomailbox -Identity $Username -Archive -ErrorAction SilentlyContinue
            if (-not $archivembox) {
                Enable-Mailbox -Archive -Identity $Username | Out-Null
            }
            else {
                "## EXO Archive is already configured for '$Username'. Skipping."
            }

        }
        catch {
            Write-Error "Enabling Mail Archive for '$Username' failed"
            Write-Error $_
        }
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

if ($ResetPassword) {
    # Check if user has MFA methods already
    # "Find phone auth. methods"
    $phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/authentication/phoneMethods" -Beta

    # "Find Authenticator App auth methods"
    $appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/authentication/microsoftAuthenticatorMethods" -Beta

    # "Find Classic OATH App auth methods"
    $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/authentication/softwareOathMethods" -Beta

    # "Find FIDO2 auth methods"
    $fido2AMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/authentication/fido2Methods" -Beta

    if (-not ($phoneAMs -or $appAMs -or $OATHAMs -or $fido2AMs)) {
        $initialPassword = ("Initial" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
        $body = @{
            passwordProfile = @{
                forceChangePasswordNextSignIn = $true
                password                      = $initialPassword
            }
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null
        "## Password for '$UserName' has been reset to:"
        "$initialPassword"
        ""
    }
    else {
        "## '$UserName' already has MFA in place. Will not reset PW."
    }
}

"## User '$UserName' successfully updated."