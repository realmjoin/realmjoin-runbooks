# This runbook will create a new user account
#
# It will try to guess values if needed.

# Requires #Requires -Module AzureAD, RealmJoin.RunbookHelper

param (
    # Option - Use at least "givenName" and "surname" to create the user.
    [string]$givenName = "",
    [string]$surname = "",
    # Option - Use at least "userPrincipalName" to create the user.
    [string]$userPrincipalName,
    [string]$displayName = "",
    [string]$companyName = "",
    # Option - Use at least the "mailNickName" to create the user.
    [string]$mailNickName = "",
    [string]$defaultLicense = "LIC_M365_E5",
    # Comma separated list of groups to add the user to
    [string]$defaultGroups = "",
    # Optional: Give an initial password. Otherwise, a random PW will be generated.
    [String]$initialPassword = ""

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

if ($initialPassword -eq "") {
    $initialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
    Write-Output ("Generating random initial PW.")
}

if ($userPrincipalName -eq "") {
    $tenantDetail = Get-AzureADTenantDetail
    $UPNSuffix = ($tenantDetail.VerifiedDomains | Where-Object { $_._Default }).Name
    if ($mailNickName -ne "") {
        # Try to base it on mailnickname...
        $userPrincipalName = $mailNickName + "@" + $UPNSuffix
    }
    elseif (($givenName -ne "") -and ($surname -ne "")) {
        # Try to create it from the real name...
        $userPrincipalName = $givenName + "." + $surname + "@" + $UPNSuffix
    }
    else {
        throw "Please provide a userPrincipalName"
    }
    Write-Output "Setting userPrincipalName to `"$userPrincipalName`"."
}

write-output ("Check if the username $userPrincipalName is available") 
$targetUser = Get-AzureADUser -ObjectId $userPrincipalName -ErrorAction SilentlyContinue
if ($null -ne $targetUser) {
    throw ("Username $userPrincipalName is already taken.")
}

if (($displayName -eq "") -and ($givenName -ne "") -and ($surname -ne "")) {
    $displayName = "$givenName $surname"    
    Write-Output "Setting displayName to `"$displayName`"."
}

if ($displayName -eq "") {
    $displayName = $userPrincipalName    
    Write-Output "Setting displayName to `"$displayName`"."
}

if ($mailNickName -eq "") {
    $mailNickName = $userPrincipalName.Split('@')[0]
    Write-Output "Setting mailNickName `"$mailNickName`"."
}

if ($companyName -eq "") {
    $companyName = (Get-AzureADTenantDetail).DisplayName
    Write-Output "Setting companyName to `"$companyName`"."
}

# Create password profile for new user
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
Write-Output "Setting password."
$PasswordProfile.Password = $initialPassword
Write-Output "Enforcing password change at next logon. (PasswordProfile)"
$PasswordProfile.ForceChangePasswordNextLogin = $true

Write-Output "Creating user object for $userPrincipalName"
try {
    if (($givenName -ne "") -and ($surname -ne "")) {
        $userObject = New-AzureADUser -AccountEnabled $true -DisplayName $displayName -PasswordProfile $PasswordProfile -UserPrincipalName $userPrincipalName -GivenName $givenName -Surname $surname -MailNickName $mailNickName -CompanyName $companyName -ErrorAction Stop 
    }
    else {
        $userObject = New-AzureADUser -AccountEnabled $true -DisplayName $displayName -PasswordProfile $PasswordProfile -UserPrincipalName $userPrincipalName -MailNickName $mailNickName -CompanyName $companyName -ErrorAction Stop 
    }
}
catch {
    throw "Failed to create user $userPrincipalName"
}

# Assign the default license. Continue even if this fails.
if ($defaultLicense -ne "") {
    Write-Output "Searching license group $defaultLicense."
    $group = Get-AzureADGroup -Filter "displayName eq `'$defaultLicense`'" -ErrorAction SilentlyContinue
    if (-not $group) {
        Write-Output "License group $defaultLicense not found!"
        Write-Error "License group $defaultLicense not found!"
    }
    else {
        Write-Output "Adding $userPrincipalName to $($group.displayName)"
        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
    }
}

# Assign the given groups. Continue even if this fails.
$groupsArray = $defaultGroups.split(',')
foreach ($groupname in $groupsArray) {
    if ($groupname -ne "") {
        Write-Output "Searching default group $groupname."
        $group = Get-AzureADGroup -Filter "displayName eq `'$groupname`'" -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Output "Group $groupname not found!" 
            Write-Error "Group $groupname not found!"
        }
        else {
            Write-Output "Adding $userPrincipalName to $($group.displayName)"
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
        }
    }
}

Write-Output "User $userPrincipalName successfully created. Initial PW: $initialPassword"