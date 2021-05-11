# This runbook will update the photo / avatar picture of a user
# It requires an URI to a jpeg-file and a users UPN.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
#
# Permissions:
# - AzureAD Role: User administrator

#Requires -Module AzureAD, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [string]$photoURI = "",
    [Parameter(Mandatory = $true)]
    [String] $UserName
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

#region authentication
$connectionName = "AzureRunAsConnection"

# Get the connection "AzureRunAsConnection"
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

write-output "Authenticate to AzureAD with AzureRunAsConnection..." 
try {
    Connect-AzureAD -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -ApplicationId $servicePrincipalConnection.ApplicationId -TenantId $servicePrincipalConnection.TenantId | Out-Null
}
catch {
    Write-Error $_
    throw "AzureAD login failed"
}
#endregion

write-output ("Find the user object " + $UserName) 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

write-output ("Download the photo from URI " + $photoURI)
try {
    # "ImageByteArray" is broken in PS5, so will use a file.
    #$photo = (Invoke-WebRequest -Uri $photoURI -UseBasicParsing).Content
    Invoke-WebRequest -Uri $photoURI -OutFile ($env:TEMP + "\photo.jpg") 
}
catch {
    Write-Error $_
    throw ("Photo download from " + $photoURI + " failed.")
}

Write-Output "Set profile picture for user"
# "ImageByteArray" is broken in PS5, so will use a file.
# Set-AzureADUserThumbnailPhoto -ImageByteArray $photo -ObjectId $targetUser.ObjectId 
try {
    Set-AzureADUserThumbnailPhoto -FilePath ($env:TEMP + "\photo.jpg") -ObjectId $targetUser.ObjectId -ErrorAction Stop
} catch {
    Write-Error $_
    Disconnect-AzureAD -Confirm:$false
    throw "Setting photo failed."
}

Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

Write-Output ("Updating profile photo for " + $UserName + " succeded.")
