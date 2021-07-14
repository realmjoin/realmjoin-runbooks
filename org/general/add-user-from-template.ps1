<#
  .SYNOPSIS
  Create a new user account from a template

  .DESCRIPTION
  Create a new user account from a template

  .PARAMETER LocationName
  Specify the users office location. Will fill more fields from template.

  .PARAMETER ManagerId
  Assign a manager for this user

  .PARAMETER AdditionalGroups
  Comma separated list of more groups to assign. e.g. "DL Sales,LIC Internal Product"

  .PARAMETER UserPrincipalName
  Overwrite the default UPN if needed 

  .PARAMETER UserTemplate
  Which user template from the JSON configuration will be used to "fill the blanks"

  .NOTES
  Permissions
  AzureAD Roles
  - User administrator
#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

param (
    # Option - Use at least "givenName" and "surname" to create the user.
    [Parameter(Mandatory = $true)]
    [string]$GivenName = "",
    [Parameter(Mandatory = $true)]
    [string]$Surname = "",
    [string]$JobTitle = "",
    [string]$LocationName = "",
    [string]$Department = "",
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Manager" } )]
    [string]$ManagerId = "",
    [string]$CompanyName = "",
    [string]$MobilePhone = "",
    [string]$AdditionalGroups = "",
    [ValidateScript( { Use-RJInterface -DisplayName "UserPrincipalName" } )]
    [string]$UserPrincipalName = "",
    [string]$UserTemplate = "default"
)

# Those are empty by default. 
$MailNickname = ""
$DisplayName = ""
$InitialPassword = ""
$UsageLocation = ""

Connect-RjRbAzureAD

#region configuration import

#"Getting Process configuration"
$processConfigRaw = Get-AutomationVariable -name "SettingsOrgAddUser" -ErrorAction SilentlyContinue
if (-not $processConfigRaw) {
    ## production default
    # $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings.json"
    ## staging default
    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/master/setup/defaults/settings.json"
    $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL 
    $processConfigRaw = $webResult.Content 
}
# Write-RjRbDebug "Process Config URL is $($processConfigURL)"

# "Getting Process configuration"
$processConfig = $processConfigRaw | ConvertFrom-Json

if (-not $processConfig.userSettings.templates.$UserTemplate) {
    throw "Unkown User Template '$UserTemplate'"
}

#endregion

# AzureAD Module is broken in regards to ErrorAction, so...
$ErrorActionPreference = "SilentlyContinue"

#region Gather information / Validate
# "Generating random initial PW."
if (-not $InitialPassword) {
    $InitialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
    #"Setting Password"
}

# "Choosing UPN, if not given"
if (-not $UserPrincipalName) {
    $tenantDetail = Get-AzureADTenantDetail
    $UPNSuffix = ($tenantDetail.VerifiedDomains | Where-Object { $_._Default }).Name
    $UserPrincipalName = ($GivenName + "." + $Surname + "@" + $UPNSuffix).ToLower()
    #"Setting userPrincipalName to `"$UserPrincipalName`"."
}

# "Check if the username $UserPrincipalName is available" 
$targetUser = Get-AzureADUser -ObjectId $UserPrincipalName 
if ($null -ne $targetUser) {
    throw ("Username $UserPrincipalName is already taken.")
}

# Prefereably contruct the displayName from the real names...
if (-not $DisplayName) {
    $DisplayName = "$GivenName $Surname"    
    #"Setting displayName to `"$DisplayName`"."
}

if (-not $MailNickname) {
    $MailNickname = $UserPrincipalName.Split('@')[0]
    #"Setting mailNickName `"$MailNickname`"."
}

# Ok, at least have some displayName...
if (-not $DisplayName) {
    $DisplayName = $MailNickname    
    #"Setting displayName to `"$MailNickname`"."
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
        if (-not $UsageLocation -and $template.validateOfficeLocation.$LocationName.usageLocation) {
            $UsageLocation = $template.validateOfficeLocation.$LocationName.usageLocation
        }
    }
}

if (-not $UsageLocation) {
    if ($template.usageLocation) {
        $UsageLocation = $template.usageLocation
    }
}

$groupsArray = $template.AADGroupsToAssign
$groupsArray += ($AdditionalGroups.split(',')).Trim()
#endregion

#region Apply / Create user
$newUserArgs = [ordered]@{
    UserPrincipalName = $UserPrincipalName
    MailNickName      = $MailNickname
    DisplayName       = $DisplayName
    AccountEnabled    = $true
    PasswordProfile   = [Microsoft.Open.AzureAD.Model.PasswordProfile]::new($initialPassword, $true <# ForceChangePasswordNextLogin #>)
}

if ($givenName) {
    $newUserArgs += @{ GivenName = $givenName }
}

if ($surname) {
    $newUserArgs += @{ Surname = $surname }
}

if ($CompanyName) {
    $newUserArgs += @{ CompanyName = $CompanyName }
}

if ($Department) {
    $newUserArgs += @{ Department = $Department }
}

if ($LocationName) {
    $newUserArgs += @{ PhysicalDeliveryOfficeName = $LocationName }
}

if ($country) {
    $newUserArgs += @{ Country = $country }
}

if ($state) {
    $newUserArgs += @{ State = $state }
}

if ($postalCode) {
    $newUserArgs += @{ PostalCode = $postalCode }
}

if ($city) {
    $newUserArgs += @{ City = $city }
}

if ($streetAddress) {
    $newUserArgs += @{ StreetAddress = $streetAddress }
}

if ($JobTitle) {
    $newUserArgs += @{ JobTitle = $JobTitle }
}

if ($MobilePhone) {
    $newUserArgs += @{ Mobile = $MobilePhone }
}

if ($UsageLocation) {
    $newUserArgs += @{ UsageLocation = $UsageLocation }
}

# $newUserArgs | Format-Table | Out-String

#"Creating user object for $UserPrincipalName"
$ErrorActionPreference = "Stop"
$userObject = New-AzureADUser @newUserArgs -ErrorAction Stop 
$ErrorActionPreference = "SilentlyContinue"

# Assign the given groups. Continue even if this fails.
foreach ($groupname in $groupsArray) {
    if ($groupname -ne "") {
        #"Searching default group $groupname."
        $group = Get-AzureADGroup -Filter "displayName eq `'$groupname`'" -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Error "Group $groupname not found! Continuing..."
        }
        else {
            #"Adding $UserPrincipalName to $($group.displayName)"
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
        }
    }
}

# Assign Manager
if ($ManagerId) {
    $ErrorActionPreference = "Stop"
    Set-AzureADUserManager -ObjectId $userObject.ObjectId -RefObjectId $ManagerId | Out-Null
    $ErrorActionPreference = "SilentlyContinue"
}
#endregion

# "Disconnecting from AzureAD."
Disconnect-AzureAD -Confirm:$false | Out-Null

Write-Output "User $UserPrincipalName successfully created. Initial PW: $InitialPassword"