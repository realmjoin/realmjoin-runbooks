# This runbook will create a new user account
#
# It will try to guess values if needed.

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param (
    # Option - Use at least "givenName" and "surname" to create the user.
    [string]$GivenName = "",
    [string]$Surname = "",
    [string]$LocationName = "",
    # Option - Use at least "userPrincipalName" to create the user.
    [string]$UserPrincipalName,
    [string]$DisplayName = "",
    [string]$CompanyName = "",
    # Option - Use at least the "mailNickName" to create the user.
    [string]$MailNickname = "",
    [string]$DefaultLicense = "",
    # Comma separated list of groups to add the user to
    [string]$DefaultGroups = "",
    # Optional: Give an initial password. Otherwise, a random PW will be generated.
    [String]$InitialPassword = ""

)

Connect-RjRbAzureAD

# AzureAD Module is broken in regards to ErrorAction, so...
$ErrorActionPreference = "SilentlyContinue"

# "Generating random initial PW."
if ($InitialPassword -eq "") {
    $InitialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
}

# "Choosing UPN, if not given"
if ($UserPrincipalName -eq "") {
    $tenantDetail = Get-AzureADTenantDetail
    $UPNSuffix = ($tenantDetail.VerifiedDomains | Where-Object { $_._Default }).Name
    if ($MailNickname -ne "") {
        # Try to base it on mailnickname...
        $UserPrincipalName = $MailNickname + "@" + $UPNSuffix
    }
    elseif (($GivenName -ne "") -and ($Surname -ne "")) {
        # Try to create it from the real name...
        $UserPrincipalName = $GivenName + "." + $Surname + "@" + $UPNSuffix
    }
    else {
        throw "Please provide a userPrincipalName"
    }
    "Setting userPrincipalName to `"$UserPrincipalName`"."
}

"Check if the username $UserPrincipalName is available" 
$targetUser = Get-AzureADUser -ObjectId $UserPrincipalName 
if ($null -ne $targetUser) {
    throw ("Username $UserPrincipalName is already taken.")
}

# Prefereably contruct the displayName from the real names...
if (($DisplayName -eq "") -and ($GivenName -ne "") -and ($Surname -ne "")) {
    $DisplayName = "$GivenName $Surname"    
    "Setting displayName to `"$DisplayName`"."
}

if ($MailNickname -eq "") {
    $MailNickname = $UserPrincipalName.Split('@')[0]
    "Setting mailNickName `"$MailNickname`"."
}

# Ok, at least have some displayName...
if ($DisplayName -eq "") {
    $DisplayName = $MailNickname    
    "Setting displayName to `"$MailNickname`"."
}

if ($CompanyName -eq "") {
    $CompanyName = (Get-AzureADTenantDetail).DisplayName
    "Setting companyName to `"$CompanyName`"."
}

# Create password profile for new user
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
"Setting password."
$PasswordProfile.Password = $InitialPassword
"Enforcing password change at next logon. (PasswordProfile)"
$PasswordProfile.ForceChangePasswordNextLogin = $true

"Creating user object for $UserPrincipalName"
try {
    if (($GivenName -ne "") -and ($Surname -ne "")) {
        $userObject = New-AzureADUser -AccountEnabled $true -DisplayName $DisplayName -PasswordProfile $PasswordProfile -UserPrincipalName $UserPrincipalName -GivenName $GivenName -Surname $Surname -MailNickName $MailNickname -CompanyName $CompanyName -ErrorAction Stop 
    }
    else {
        $userObject = New-AzureADUser -AccountEnabled $true -DisplayName $DisplayName -PasswordProfile $PasswordProfile -UserPrincipalName $UserPrincipalName -MailNickName $MailNickname -CompanyName $CompanyName -ErrorAction Stop 
    }
}
catch {
    throw "Failed to create user $UserPrincipalName"
}

# Assign the default license. Continue even if this fails.
if ($DefaultLicense -ne "") {
    "Searching license group $DefaultLicense."
    $group = Get-AzureADGroup -Filter "displayName eq `'$DefaultLicense`'" -ErrorAction SilentlyContinue
    if (-not $group) {
        "License group $DefaultLicense not found!"
        Write-Error "License group $DefaultLicense not found!"
    }
    else {
        "Adding $UserPrincipalName to $($group.displayName)"
        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
    }
}

# Assign the given groups. Continue even if this fails.
$groupsArray = $DefaultGroups.split(',')
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

# "Disconnecting from AzureAD."
Disconnect-AzureAD

Write-Output "User $UserPrincipalName successfully created. Initial PW: $InitialPassword"