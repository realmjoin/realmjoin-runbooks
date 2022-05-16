
<#
  .SYNOPSIS
  Create an AAD temporary access pass for a user.

  .DESCRIPTION
  Create an AAD temporary access pass for a user.

  .PARAMETER LifetimeInMinutes
  Time the pass will stay valid in minutes

  .NOTES
  Permissions needed:
  - UserAuthenticationMethod.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
             "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String]$UserName,
    [ValidateScript( { Use-RJInterface -Type Number -DisplayName "Lifetime"} )]
    [int] $LifetimeInMinutes = 240,
    [ValidateScript( { Use-RJInterface -Type Number -DisplayName "One time use only"} )]
    [bool] $OneTimeUseOnly = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

"## Trying to create an Temp. Access Pass (TAP) for user '$UserName'"

Connect-RjRbGraph

try {
# "Making sure, no old temp. access passes exist for $UserName"
$OldPasses = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Beta
$OldPasses | ForEach-Object {
    Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods/$($_.id)" -Beta -Method Delete | Out-Null
} } catch {
    "Querying of existing Temp. Access Passes failed. Maybe you are missing Graph API permissions:"
    "- 'UserAuthenticationMethod.ReadWrite.All' (API)"

    throw ($_) 
}

try {

# "Creating new temp. access pass"
$body = @{
    "@odata.type"       = "#microsoft.graph.temporaryAccessPassAuthenticationMethod";
    "lifetimeInMinutes" = $LifetimeInMinutes;
    "isUsableOnce"      = $OneTimeUseOnly
}
$pass = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Body $body -Beta -Method Post 

if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
    "## Beware: The use of Temporary access passes seems to be disabled for this user."
    ""
}

"## New Temporary access pass for '$UserName' with a lifetime of $LifetimeInMinutes minutes has been created:" 
""
"$($pass.temporaryAccessPass)"
} catch {
    "Creation of a new Temp. Access Pass failed. Maybe you are missing Graph API permissions:"
    "- 'UserAuthenticationMethod.ReadWrite.All' (API)"
    throw ($_)
}