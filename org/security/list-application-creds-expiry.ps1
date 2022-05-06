<#
  .SYNOPSIS
  List expiry date of all AppRegistration  credentials

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
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [bool] $listOnlyExpiring = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Days before credential expiry" } )]
    [int] $Days = 30,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph
[array]$apps = @()
$apps = Invoke-RjRbRestMethodGraph -Resource "/applications" -FollowPaging
$apps += Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" 

$date = Get-Date

foreach ($app in $apps) {
    if (($app.keyCredentials) -or ($app.passwordCredentials)) {
    
        $app.keyCredentials | ForEach-Object {
            $enddate = [datetime]$_.endDateTime
            if ((New-TimeSpan -Start $date -End $enddate).days -le $Days) {
                "## App DisplayName: $($app.displayName)"
                "## App Id: $($app.appId)"
                ""
                "Cert DisplayName: $($_.displayName)"
                "Cert ID: $($_.keyId)"
                #"Cert EndDateTime: $($_.endDateTime)"

                "Days left: $((New-TimeSpan -Start $date -End $enddate).days)"
                ""
            }
        }
        $app.passwordCredentials | ForEach-Object {
            $enddate = [datetime]$_.endDateTime
            if ((New-TimeSpan -Start $date -End $enddate).days -le $Days) {
                "## App DisplayName: $($app.displayName)"
                "## App Id: $($app.appId)"
                ""
                "Client Secret DisplayName: $($_.displayName)"
                "Client Secret ID: $($_.keyId)"
                #"Client Secret EndDateTime: $($_.endDateTime)"
            
                "Days left: $((New-TimeSpan -Start $date -End $enddate).days)"
                ""
            }
        }
    }
}