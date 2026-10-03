<#
	.SYNOPSIS
	Update profile details, groups and mailbox settings of this user

	.DESCRIPTION
	Updates the profile of this user in Entra ID, such as name, company, address, job title and manager. It can also add the user to a license group and further groups, enable the Exchange Online archive and reset the password. Only the fields you fill in are changed; a missing display name or company is filled in automatically.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER GivenName
	New first name.

	.PARAMETER Surname
	New last name.

	.PARAMETER DisplayName
	New display name as shown in Microsoft 365.

	.PARAMETER CompanyName
	Company the user belongs to.

	.PARAMETER City
	City of the user's address.

	.PARAMETER Country
	Country of the user's address.

	.PARAMETER JobTitle
	Job title shown in the profile.

	.PARAMETER Department
	Department the user works in.

	.PARAMETER OfficeLocation
	Office or building the user works at.

	.PARAMETER PostalCode
	Postal code of the user's address.

	.PARAMETER PreferredLanguage
	Language code such as en-US or de-DE.

	.PARAMETER State
	State or region of the user's address.

	.PARAMETER StreetAddress
	Street and house number of the user's address.

	.PARAMETER UsageLocation
	Two-letter country code that decides which licenses the user may get, for example DE.

	.PARAMETER ManagerId
	User who becomes the manager of this user.

	.PARAMETER DefaultLicense
	Display name of the group that assigns the license; the user is added to it.

	.PARAMETER DefaultGroups
	Display names of groups the user is added to, separated by commas.

	.PARAMETER EnableEXOArchive
	Turns on the Exchange Online archive mailbox for the user.

	.PARAMETER ResetPassword
	Sets a generated start password, shown in the output, that must be changed at the next sign-in. Skipped when the user already has MFA methods.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			},
			"GivenName": {
				"DisplayName": "First name"
			},
			"Surname": {
				"DisplayName": "Last name"
			},
			"DisplayName": {
				"DisplayName": "Display name"
			},
			"CompanyName": {
				"DisplayName": "Company"
			},
			"JobTitle": {
				"DisplayName": "Job title"
			},
			"OfficeLocation": {
				"DisplayName": "Office location"
			},
			"PostalCode": {
				"DisplayName": "Postal code"
			},
			"PreferredLanguage": {
				"DisplayName": "Preferred language"
			},
			"StreetAddress": {
				"DisplayName": "Street address"
			},
			"UsageLocation": {
				"DisplayName": "Usage location"
			},
			"DefaultLicense": {
				"DisplayName": "License group to assign"
			},
			"DefaultGroups": {
				"DisplayName": "Groups to add"
			},
			"ManagerId": {
				"DisplayName": "Manager"
			},
			"EnableEXOArchive": {
				"DisplayName": "Enable the archive mailbox?"
			},
			"ResetPassword": {
				"DisplayName": "Reset the password?"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

# Suppress false positive from PSScriptAnalyzer - parameters are used indirectly via Get-Variable in the addToUserArgs helper function
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "City")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "Country")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "JobTitle")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "Department")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "OfficeLocation")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "PostalCode")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "PreferredLanguage")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "State")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "StreetAddress")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "UsageLocation")]
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Manager" -Filter "userType eq 'Member'" } )]
    [string]$ManagerId = "",
    [string]$DefaultLicense = "",
    [string]$DefaultGroups = "",
    [bool]$EnableEXOArchive = $false,
    [bool]$ResetPassword = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
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

    # Assign a manager
    if ($ManagerId) {
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($ManagerId)"
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/manager/`$ref" -Method Put -Body $body | Out-Null
        "## Manager updated for '$UserName'."
    }

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