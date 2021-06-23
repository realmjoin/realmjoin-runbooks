#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Will create a new user account from a user template

  .DESCRIPTION
  Will create a new user account from a user template

  .PARAMETER LocationName
  Specify the users office location. Will fill more fields like country, city, streetAddress if possible

  .PARAMETER ManagerId
  Choose the manager for this user

  .PARAMETER AdditionalGroups
  Comma separated list of more groups to assign. e.g. "DL Sales,LIC Internal Product"

  .PARAMETER UserPrincipalName
  You can overwrite the default UPN if needed. 

  .PARAMETER UserTemplate
  This will control, which user template from the JSON configuration will be used to "fill the blanks".
#>


param (
    # Option - Use at least "givenName" and "surname" to create the user.
    [Parameter(Mandatory = $true)]
    [string]$GivenName = "",
    [Parameter(Mandatory = $true)]
    [string]$Surname = "",
    [string]$JobTitle = "",
    [string]$LocationName = "",
    [string]$Department = "",
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Manager"} )]
    [string]$ManagerId = "",
    [string]$CompanyName = "",
    [string]$MobilePhoneNumber = "",
    [string]$AdditionalGroups = "",
    [string]$UserPrincipalName = "",
    [string]$UserTemplate = "default"
)

# Those are empty by default. Listing them for completeness.
# $MailNickname = ""
# $DisplayName = ""
# $InitialPassword = ""



Connect-RjRbAzureAD

#region configuration import
# "Getting Process configuration URL"
$processConfigURL = Get-AutomationVariable -name "SettingsSourceOrgAddUser" -ErrorAction SilentlyContinue
if (-not $processConfigURL) {
    ## production default
    # $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings.json"
    ## staging default
    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/master/setup/defaults/settings.json"
}
# Write-RjRbDebug "Process Config URL is $($processConfigURL)"

# "Getting Process configuration"
$webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL 
$processConfig = $webResult.Content | ConvertFrom-Json

if (-not $processConfig.userSettings.templates.$UserTemplate) {
    throw "Unkown User Template '$UserTemplate'"
}
#endregion

# AzureAD Module is broken in regards to ErrorAction, so...
$ErrorActionPreference = "SilentlyContinue"

#region Gather information / Validate
# "Generating random initial PW."
if ($InitialPassword -eq "") {
    $InitialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
}

# "Choosing UPN, if not given"
if (-not $UserPrincipalName) {
    $tenantDetail = Get-AzureADTenantDetail
    $UPNSuffix = ($tenantDetail.VerifiedDomains | Where-Object { $_._Default }).Name
    if (-not $MailNickname) {
        # Try to base it on mailnickname...
        $UserPrincipalName = $MailNickname + "@" + $UPNSuffix
    }
    elseif ((-not $GivenName) -and (-not $Surname)) {
        # Try to create it from the real name...
        $UserPrincipalName = $GivenName + "." + $Surname + "@" + $UPNSuffix
    }
    else {
        throw "Please provide a userPrincipalName"
    }
    # "Setting userPrincipalName to `"$UserPrincipalName`"."
}

# "Check if the username $UserPrincipalName is available" 
$targetUser = Get-AzureADUser -ObjectId $UserPrincipalName 
if ($null -ne $targetUser) {
    throw ("Username $UserPrincipalName is already taken.")
}

# Prefereably contruct the displayName from the real names...
if (($DisplayName -eq "") -and ($GivenName -ne "") -and ($Surname -ne "")) {
    $DisplayName = "$GivenName $Surname"    
    #    "Setting displayName to `"$DisplayName`"."
}

if ($MailNickname -eq "") {
    $MailNickname = $UserPrincipalName.Split('@')[0]
    #    "Setting mailNickName `"$MailNickname`"."
}

# Ok, at least have some displayName...
if ($DisplayName -eq "") {
    $DisplayName = $MailNickname    
    #    "Setting displayName to `"$MailNickname`"."
}

# Read more info from the User Template
$template = $processConfig.userSettings.templates.$UserTemplate

if (-not $CompanyName) {
    if ($template.company) {
        $CompanyName = $template.company
    }
}

if (-not $CompanyName) {
    $CompanyName = (Get-AzureADTenantDetail).DisplayName
    # "Setting companyName to `"$CompanyName`"."
}

if ($CompanyName) {
    if ($template.validateCompany -and -not $template.validateCompany.$CompanyName) {
        throw "Please provide a valid company name."
    }     
}

if (-not $Department) {
    if ($template.department) {
        $Department = $template.department
    }
}

if ($Department) {
    if ($template.validateDepartment -and -not $template.validateDepartment.$Department) {
        throw "Please provide a valid department."
    }     
}

if (-not $LocationName) {
    if ($template.location) {
        $LocationName = $template.location
    }
}

if ($LocationName) {
    if ($template.validateOfficeLocation) { 
        if (-not $template.validateOfficeLocation.$LocationName) {
            throw "Please provide a valid location name."
        } 
        if (-not $streetAddress -and $template.validateOfficeLocation.$LocationName.streetAddress) {
            $streetAddress = $template.validateOfficeLocation.$LocationName.streetAddress
        }
        if (-not $city -and $template.validateOfficeLocation.$LocationName.city) {
            $city = $template.validateOfficeLocation.$LocationName.city
        }
        if (-not $state -and $template.validateOfficeLocation.$LocationName.state) {
            $state = $template.validateOfficeLocation.$LocationName.state
        }
        if (-not $postalCode -and $template.validateOfficeLocation.$LocationName.postalCode) {
            $postalCode = $template.validateOfficeLocation.$LocationName.postalCode
        }        
        if (-not $country -and $template.validateOfficeLocation.$LocationName.country) {
            $country = $template.validateOfficeLocation.$LocationName.country
        }
    }
}

$groupsArray = $template.AADGroupsToAssign
$groupsArray += $AdditionalGroups.split(',')
#endregion

#region Apply / Create user
$newUserArgs = [ordered]@{
    userPrincipalName = $UserPrincipalName
    mailNickName      = $MailNickname
    displayName       = $DisplayName
    accountEnabled    = $true
    passwordProfile   = [Microsoft.Open.AzureAD.Model.PasswordProfile]::new($initialPassword, $true <# ForceChangePasswordNextLogin #>)
}

if ($givenName) {
    $newUserArgs += @{ givenName = $givenName }
}
if ($surname) {
    $newUserArgs += @{ surname = $surname }
}

if ($CompanyName) {
    $newUserArgs += @{ companyName = $CompanyName }
}

if ($Department) {
    $newUserArgs += @{ department = $Department }
}

if ($LocationName) {
    $newUserArgs += @{ officeLocation = $LocationName }
}

if ($country) {
    $newUserArgs += @{ country = $country }
}

if ($state) {
    $newUserArgs += @{ state = $state }
}

if ($postalCode) {
    $newUserArgs += @{ postalCode = $postalCode }
}

if ($city) {
    $newUserArgs += @{ city = $city }
}

if ($streetAddress) {
    $newUserArgs += @{ streetAddress = $streetAddress }
}

if ($JobTitle) {
    $newUserArgs += @{ jobTitle = $JobTitle }
}

if ($MobilePhoneNumber) {
    $newUserArgs += @{ mobilePhone = $MobilePhoneNumber }
}

#"Creating user object for $UserPrincipalName"
$ErrorActionPreference = "Stop"
try {
    if (($GivenName -ne "") -and ($Surname -ne "")) {
        $userObject = New-AzureADUser @newUserArgs -ErrorAction Stop 
    }
}
catch {
    throw "Failed to create user $UserPrincipalName"
}
$ErrorActionPreference = "SilentlyContinue"

# Assign the given groups. Continue even if this fails.
foreach ($groupname in $groupsArray) {
    if ($groupname -ne "") {
        "Searching default group $groupname."
        $group = Get-AzureADGroup -Filter "displayName eq `'$groupname`'" -ErrorAction SilentlyContinue
        if (-not $group) {
            "Group $groupname not found!" 
            Write-Error "Group $groupname not found!"
        }
        else {
            "Adding $UserPrincipalName to $($group.displayName)"
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
        }
    }
}

# Assign Manager
if ($ManagerId) {
    Set-AzureADUserManager -ObjectId $userObject.ObjectId -RefObjectId $ManagerId | Out-Null
}

#endregion

# "Disconnecting from AzureAD."
Disconnect-AzureAD -Confirm:$false | Out-Null

Write-Output "User $UserPrincipalName successfully created. Initial PW: $InitialPassword"