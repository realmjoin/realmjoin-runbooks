# This runbook will create an AAD temporary access pass for a user. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    # How long (starting immediately) is the pass valid?
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [int] $lifetimeInMinutes = 240,
    # Is this a one-time pass (prefered); will be usable multiple times otherwise
    [bool] $oneTimeUseOnly = $true
)

#region module check
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

Test-ModulePresent "MEMPSToolkit"
Test-ModulePresent "RealmJoin.RunbookHelper"
#endregion

#region Authentication
# "Connect to Graph API..."
Connect-RjRbGraph
#endregion

"Making sure, no old temp. access passes exist for $UserName"
Remove-AadUserTemporaryAccessPass -authToken $Global:RjRbGraphAuthHeaders -userID $UserName

"Creating new temp. access pass"
$pass = New-AadUserTemporaryAccessPass -authToken $Global:RjRbGraphAuthHeaders -userID $UserName -oneTimeUse $oneTimeUseOnly -lifetimeInMinutes $lifetimeInMinutes

if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
    "Beware: The use of Temporary access passes seems to be disabled for this user."
}

"New Temporary access pass for $UserName with a lifetime of $lifetimeInMinutes minutes has been created: $($pass.temporaryAccessPass)"
