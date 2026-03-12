<#
    .SYNOPSIS
    Create a temporary access pass for a user

    .DESCRIPTION
    Creates a new Temporary Access Pass (TAP) authentication method for a user in Microsoft Entra ID. Existing TAPs for the user are removed before creating a new one.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER LifetimeInMinutes
    Lifetime of the temporary access pass in minutes.

    .PARAMETER OneTimeUseOnly
    If set to true, the pass can be used only once.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number -DisplayName "Lifetime" } )]
    [int] $LifetimeInMinutes = 240,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Number -DisplayName "One time use only" } )]
    [bool] $OneTimeUseOnly = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to create an Temp. Access Pass (TAP) for user '$UserName'"

Connect-RjRbGraph

try {
    # "Making sure, no old temp. access passes exist for $UserName"
    $OldPasses = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Beta
    $OldPasses | ForEach-Object {
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods/$($_.id)" -Beta -Method Delete | Out-Null
    }
}
catch {
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
}
catch {
    "Creation of a new Temp. Access Pass failed. Maybe you are missing Graph API permissions:"
    "- 'UserAuthenticationMethod.ReadWrite.All' (API)"
    throw ($_)
}