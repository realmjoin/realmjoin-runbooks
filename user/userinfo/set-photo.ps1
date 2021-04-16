# This runbook will update the photo / avatar picture of a user
# It requires an URI to a jpeg-file and a users UPN.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

param(
    [Parameter(Mandatory = $true)]
    [string]$photoURI = "",
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "AzureAD"
$thisRunbook = "rjgit-user_userinfo_set-photo"
$thisRunbookParams = @{
    "reRun"    = $true;
    "photoURI" = $photoURI;
    "UserName" = $UserName
}

#region Module Management
Write-Output ("Check if " + $neededModule + " is available")
$moduleInstallerRunbook = "rjgit-setup_import-module-from-gallery" 

if (-not $reRun) { 
    if (-not (Get-Module -ListAvailable $neededModule)) {
        Write-Output ("Installing " + $neededModule + ". This might take several minutes.")
        $runbookJob = Start-AutomationRunbook -Name $moduleInstallerRunbook -Parameters @{"moduleName" = $neededModule; "waitForDeployment" = $true }
        Wait-AutomationJob -Id $runbookJob.Guid -TimeoutInMinutes 10
        Write-Output ("Restarting Runbook and stopping this run.")
        Start-AutomationRunbook -Name $thisRunbook -Parameters $thisRunbookParams
        exit
    }
} 

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

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
