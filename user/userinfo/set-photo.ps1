# This runbook will update the photo / avatar picture of a user
# It requires an URI to a jpeg-file and a users UPN.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

# Required modules. Will be honored by Azure Automation.
using module AzureAD

param(
    [string]$photoURI = "",
    [string]$userPrincipalName
)

$connectionName = "AzureRunAsConnection"

# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

write-output "Authenticate to AzureAD with AzureRunAsConnection..." 
try {
    $session = Connect-AzureAD -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -ApplicationId $servicePrincipalConnection.ApplicationId -TenantId $servicePrincipalConnection.TenantId 
}
catch {
    Write-Error $_.Exception
    throw "AzureAD login failed"
}

write-output ("Find the user object " + $userPrincipalName) 
$targetUser = Get-AzureADUser -ObjectId $userPrincipalName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $userPrincipalName + " not found.")
}

write-output ("Download the photo from URI " + $photoURI)
try {
    # "ImageByteArray" is broken in PS5, so will use a file.
    #$photo = (Invoke-WebRequest -Uri $photoURI -UseBasicParsing).Content
    Invoke-WebRequest -Uri $photoURI -OutFile ($env:TEMP + "\photo.jpg") 
}
catch {
    Write-Error $_.Exception
    throw ("Photo download from " + $photoURI + " failed.")
}

Write-Output "Set profile picture for user"
# "ImageByteArray" is broken in PS5, so will use a file.
# Set-AzureADUserThumbnailPhoto -ImageByteArray $photo -ObjectId $targetUser.ObjectId 
Set-AzureADUserThumbnailPhoto -FilePath ($env:TEMP + "\photo.jpg") -ObjectId $targetUser.ObjectId

Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false
