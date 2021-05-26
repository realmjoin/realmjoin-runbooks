# This runbook will update fields of an existing user object.

#Requires -Module RealmJoin.RunbookHelper, AzureAD

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

#region module check
$neededModule = "AzureAD"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

#region Authentication
$connectionName = "AzureRunAsConnection"

# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

write-output "Authenticate to AzureAD with AzureRunAsConnection..." 
try {
    Connect-AzureAD -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -ApplicationId $servicePrincipalConnection.ApplicationId -TenantId $servicePrincipalConnection.TenantId -ErrorAction Stop | Out-Null
}
catch {
    Write-Error $_.Exception
    throw "AzureAD login failed"
}
#endregion

write-output ("Searching for user $UserName.") 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

#region atomic changes
if ($givenName) {
    try {
        Write-Output "Setting givenName to `"$givenName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -GivenName $givenName 
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($surname) {
    try {
        Write-Output "Setting surname to `"$surname`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -Surname $surname
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($displayName) {
    try {
        Write-Output "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($companyName) {
    try {
        Write-Output "Setting companyName to `"$companyName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -CompanyName $companyName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($city) {
    try {
        Write-Output "Setting city to `"$city`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -City $city
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($country) {
    try {
        Write-Output "Setting country to `"$country`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -Country $country
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($jobTitle) {
    try {
        Write-Output "Setting jobTitle to `"$jobTitle`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -JobTitle $jobTitle
    }
    catch {
        throw "Updating user object failed!"
    }
}

# Be aware - naming difference local AD and AzureAD!
if ($officeLocation) {
    try {
        Write-Output "Setting officeLocation to `"$officeLocation`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PhysicalDeliveryOfficeName $officeLocation
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($postalCode) {
    try {
        Write-Output "Setting postalCode to `"$postalCode`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PostalCode $postalCode
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($preferredLanguage) {
    try {
        Write-Output "Setting preferredLanguage to `"$preferredLanguage`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -PreferredLanguage $preferredLanguage
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($state) {
    try {
        Write-Output "Setting state to `"$state`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -State $state
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($streetAddress) {
    try {
        Write-Output "Setting streetAddress to `"$streetAddress`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -StreetAddress $streetAddress
    }
    catch {
        throw "Updating user object failed!"
    }   
}

if ($usageLocation) {
    try {
        Write-Output "Setting usageLocation to `"$usageLocation`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -UsageLocation $usageLocation
    }
    catch {
        throw "Updating user object failed!"
    }   
}
#endregion

#load new state from AzureAD
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue

#region inference updates
if (($null -eq $targetUser.DisplayName) -and ($null -ne $targetUser.GivenName) -and ($null -ne $targetUser.Surname)) {
    $displayName = ($targetUser.GivenName + " " + $targetUser.Surname)
    try {
        Write-Output "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
    
} elseif ($null -eq $targetUser.DisplayName) {
    $displayName = $targetUser.MailNickName
    try {
        Write-Output "Setting displayName to `"$displayName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -DisplayName $displayName
    }
    catch {
        throw "Updating user object failed!"
    }
}

if ($null -eq $targetUser.Company) {
    $companyName = (Get-AzureADTenantDetail).DisplayName
    try {
        Write-Output "Setting companyName to `"$companyName`""
        Set-AzureADUser -ObjectId $targetUser.ObjectId -CompanyName $companyName
    }
    catch {
        throw "Updating user object failed!"
    }
}
#endregion

Write-Output "Disconnecting from AzureAD."
Disconnect-AzureAD

Write-Output "User $UserName successfully updated."