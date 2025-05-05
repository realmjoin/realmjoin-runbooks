<#
  .SYNOPSIS
  List expiry date of all AppRegistration credentials

  .DESCRIPTION
  List expiry date of all AppRegistration credentials

  .NOTES
  Permissions:
   MS Graph - Application Permission
    Application.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "listOnlyExpiring": {
              "Select": {
                "Options": [
                    {
                        "Display": "List only credentials about to expire",
                        "Value": true
                    },
                    {
                        "Display": "List all credentials",
                        "Value": false,
                        "Customization": {
                            "Hide": [
                                "Days"
                            ]
                        }
                    }
                ]
              }
            },
            "Days": {
                "DisplayName": "Days before credential expiry"
            },
            "ApplicationIds": {
                "DisplayName": "Application IDs",
                "Type": "string",
                "Description": "Comma-separated list of Application IDs to check"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [bool] $listOnlyExpiring = $true,
    [int] $Days = 30,
    [string] $ApplicationIds,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Split the comma-separated application IDs into an array and trim whitespace
$ApplicationIdArray = $ApplicationIds -split "," | ForEach-Object { $_.Trim() }

Connect-RjRbGraph
[array]$apps = @()
$apps = Invoke-RjRbRestMethodGraph -Resource "/applications" -FollowPaging
$apps += Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals"

$date = Get-Date

foreach ($app in $apps) {
    if ($ApplicationIdArray -and ($app.appId -notin $ApplicationIdArray)) {
        continue
    }

    if (($app.keyCredentials) -or ($app.passwordCredentials)) {

        $app.keyCredentials | ForEach-Object {
            $enddate = [datetime]$_.endDateTime
            $daysLeft = (New-TimeSpan -Start $date -End $enddate).days
            if ($listOnlyExpiring) {
                if ($daysLeft -le $Days) {
                    "## App DisplayName: $($app.displayName)"
                    "## App Id: $($app.appId)"
                    ""
                    "Cert DisplayName: $($_.displayName)"
                    "Cert ID: $($_.keyId)"
                    #"Cert EndDateTime: $($_.endDateTime)"
                    "Days left: $daysLeft"
                    ""
                }
            }
            else {
                "## App DisplayName: $($app.displayName)"
                "## App Id: $($app.appId)"
                ""
                "Cert DisplayName: $($_.displayName)"
                "Cert ID: $($_.keyId)"
                #"Cert EndDateTime: $($_.endDateTime)"
                "Days left: $daysLeft"
                ""
            }
        }

        $app.passwordCredentials | ForEach-Object {
            $enddate = [datetime]$_.endDateTime
            $daysLeft = (New-TimeSpan -Start $date -End $enddate).days
            if ($listOnlyExpiring) {
                if ($daysLeft -le $Days) {
                    "## App DisplayName: $($app.displayName)"
                    "## App Id: $($app.appId)"
                    ""
                    "Client Secret DisplayName: $($_.displayName)"
                    "Client Secret ID: $($_.keyId)"
                    #"Client Secret EndDateTime: $($_.endDateTime)"
                    "Days left: $daysLeft"
                    ""
                }
            }
            else {
                "## App DisplayName: $($app.displayName)"
                "## App Id: $($app.appId)"
                ""
                "Client Secret DisplayName: $($_.displayName)"
                "Client Secret ID: $($_.keyId)"
                #"Client Secret EndDateTime: $($_.endDateTime)"
                "Days left: $daysLeft"
                ""
            }
        }
    }
}
