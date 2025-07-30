<#
  .SYNOPSIS
  List expiry date of all AppRegistration credentials

  .DESCRIPTION
  List the expiry date of all AppRegistration credentials, including Client Secrets and Certificates.
  Optionally, filter by Application IDs and list only those credentials that are about to expire.

  .PARAMETER listOnlyExpiring
  If set to true, only credentials that are about to expire within the specified number of days will be listed.
  If set to false, all credentials will be listed regardless of their expiry date.

  .PARAMETER Days
  The number of days before a credential expires to consider it "about to expire".

  .PARAMETER ApplicationIds
  A comma-separated list of Application IDs to filter the credentials.

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
