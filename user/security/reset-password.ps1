# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $enableUserIfNeeded = $true
)

# Optional: Set a password for every reset. Otherwise, a random PW will be generated every time (prefered!).
[String] $initialPassword = ""

Connect-RjRbAzureAD

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "SilentlyContinue"

# "Find the user object $UserName"
$targetUser = Get-AzureADUser -ObjectId $UserName 
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"

if ($enableUserIfNeeded) {
    "Enabling user sign in"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $true | Out-Null
}

if ($initialPassword -eq "") {
    $initialPassword = ("Reset" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
#    "Generating initial PW: $initialPassword"
}

$encPassword = ConvertTo-SecureString -String $initialPassword -AsPlainText -Force

#"Setting PW for user " + $UserName" 
Set-AzureADUserPassword -ObjectId $targetUser.ObjectId -Password $encPassword -ForceChangePasswordNextLogin $true | Out-Null

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

"Password for $UserName has been reset to: '$initialPassword'. User will have to change PW at next login."
