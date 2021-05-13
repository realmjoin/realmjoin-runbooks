# This runbook will will disable a device in AzureAD. 
#
# This runbook uses both AzureAD- and Graph-modules to avoid performance-issues with large directories.
# 
# Permissions (Graph):
# - Device.Read.All
#
# Roles (AzureAD):
# - Cloud Device Administrator

#Requires -Module AzureAD, RealmJoin.RunbookHelper, MEMPSToolkit

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $OrganizationId
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

$neededModule = "MEMPSToolkit"

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

$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

write-output "Searching DeviceId $DeviceID."
# Sadly, Get-AzureADDevices can not filter by deviceId. Will use MS Graph / MEMPSToolkit.
$targetDevice = Get-AadDevices -deviceId $DeviceId -authToken $token
if ($null -eq $targetDevice) {
    throw ("DeviceId $DeviceId not found.")
} 

if ($targetDevice.accountEnabled) {
    Write-Output "Disabling device $($targetDevice.displayName) in AzureAD."
    # Sadly, MS Graph does not allow to disable a device using app credentials. Using AzureAD.
    try {
        Set-AzureADDevice -AccountEnabled $false -ObjectId $targetDevice.id -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Disabling of device $($targetDevice.displayName) failed"
    }
}
else {
    Write-Output "Device $($targetDevice.displayName) is already disabled in AzureAD."
}

Write-Output "Disconnecting from AzureAD"
Disconnect-AzureAD

Write-Output "Device $($targetDevice.displayName) with DeviceId $DeviceId is disabled."

