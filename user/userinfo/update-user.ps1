# This runbook will update fields of an existing user object.

# Requires #Requires -Module AzureAD, RealmJoin.RunbookHelper

param (
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [string]$givenName,
    [string]$surname,
    [string]$displayName,
    [string]$companyName,
    [string]$city,
    [string]$country,
    [string]$jobTitle,
    # think "physicalDeliveryOfficeName" if you are coming from on-prem
    [string]$officeLocation,
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [string]$postalCode,
    [string]$preferredLanguage,
    [string]$state,
    [string]$streetAddress,
    [string]$usageLocation

)

#region Module check
function Test-ModulePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$neededModule
    )
    if (-not (Get-Module -ListAvailable $neededModule)) {
        throw ($neededModule + " is not available and can not be installed automatically. Please check.")
    }
    else {
        Import-Module $neededModule
        # "Module " + $neededModule + " is available."
    }
}

Test-ModulePresent "AzureAD"
Test-ModulePresent "RealmJoin.RunbookHelper"
#endregion

#region Authentication
# "Connecting to AzureAD"
Connect-RjRbAzureAD
#endregion

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "SilentlyContinue"

# "Searching for user $UserName."
$targetUser = Get-AzureADUser -ObjectId $UserName 
if (-not $targetUser) {
    throw ("User $UserName not found.")
}


# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"

#region atomic changes
if ($givenName) {
    try {
        "Setting givenName to `"$givenName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -GivenName $givenName 
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($surname) {
    try {
        "Setting surname to `"$surname`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -Surname $surname
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($displayName) {
    try {
        "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($companyName) {
    try {
        "Setting companyName to `"$companyName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -CompanyName $companyName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($city) {
    try {
        "Setting city to `"$city`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -City $city
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($country) {
    try {
        "Setting country to `"$country`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -Country $country
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($jobTitle) {
    try {
        "Setting jobTitle to `"$jobTitle`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -JobTitle $jobTitle
    }
    catch {
        throw "Updating user object failed!"
    }
}

# Be aware - naming difference local AD and AzureAD!
if ($officeLocation) {
    try {
        "Setting officeLocation to `"$officeLocation`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PhysicalDeliveryOfficeName $officeLocation
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($postalCode) {
    try {
        "Setting postalCode to `"$postalCode`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PostalCode $postalCode
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($preferredLanguage) {
    try {
        "Setting preferredLanguage to `"$preferredLanguage`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PreferredLanguage $preferredLanguage
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($state) {
    try {
        "Setting state to `"$state`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -State $state
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($streetAddress) {
    try {
        "Setting streetAddress to `"$streetAddress`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -StreetAddress $streetAddress
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($usageLocation) {
    try {
        "Setting usageLocation to `"$usageLocation`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -UsageLocation $usageLocation
    }
    catch {
        throw "Updating user object failed!"
    }   
}
#endregion

#load new state from AzureAD
$targetUser = Get-AzureADUser -ObjectId $UserName

#region inference updates
if ((-not $targetUser.DisplayName) -and ($targetUser.GivenName) -and ($targetUser.Surname)) {
    $displayName = ($targetUser.GivenName + " " + $targetUser.Surname)
    try {
        "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
    
} elseif (-not $targetUser.DisplayName) {
    $displayName = $targetUser.MailNickName
    try {
        "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if (-not $targetUser.CompanyName) {
    $companyName = (Get-AzureADTenantDetail).DisplayName
    try {
        "Setting companyName to `"$companyName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -CompanyName $companyName
    }
    catch {
        throw "Updating user object failed!"
    }
}
#endregion

"Disconnecting from AzureAD."
Disconnect-AzureAD

"User $UserName successfully updated."