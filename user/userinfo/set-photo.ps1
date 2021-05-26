# This runbook will update the photo / avatar picture of a user
# It requires an URI to a jpeg-file and a users UPN.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
#
# Permissions:
# - AzureAD Role: User administrator
#
# If you need a demo-picture: https://www.gravatar.com/avatar/205e460b479e2e5b48aec07710c08d50 (taken from https://en.gravatar.com/site/implement/images/)

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [string]$photoURI = "",
    [Parameter(Mandatory = $true)]
    [String] $UserName
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

"Find the user object $UserName"
$targetUser = Get-AzureADUser -ObjectId $UserName 
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"


"Download the photo from URI $photoURI"
try {
    # "ImageByteArray" is broken in PS5, so will use a file.
    #$photo = (Invoke-WebRequest -Uri $photoURI -UseBasicParsing).Content
    Invoke-WebRequest -Uri $photoURI -OutFile ($env:TEMP + "\photo.jpg") 
}
catch {
    Write-Error $_
    throw ("Photo download from $photoURI failed.")
}

"Set profile picture for user"
# "ImageByteArray" is broken in PS5, so will use a file.
# Set-AzureADUserThumbnailPhoto -ImageByteArray $photo -ObjectId $targetUser.ObjectId 
try {
    Set-AzureADUserThumbnailPhoto -FilePath ($env:TEMP + "\photo.jpg") -ObjectId $targetUser.ObjectId 
} catch {
    Write-Error $_
    Disconnect-AzureAD -Confirm:$false
    throw "Setting photo failed."
}

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

"Updating profile photo for $UserName succeded."
