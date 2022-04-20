<#
  .SYNOPSIS
  Create a room resource.

  .DESCRIPTION
  Create a room resource.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Select": {
                    "Options": [
                        {
                            "Display": "Turn mailbox into shared mailbox",
                            "Customization": {
                                "Default": {
                                    "Delete": false
                                }
                            }
                        }, {
                            "Display": "turn shared mailbox back into regular mailbox",
                            "Customization": {
                                "Default": {
                                    "Delete": true
                                }
                            }
                        }
                    ]
                },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" },ActiveDirectory
param (
    [ValidateScript( { Use-RJInterface -DisplayName "Maximum Age for a Password" } )]
    [int] $Days = 30,
    [ValidateScript( { Use-RJInterface -DisplayName "Delete abandoned devices" } )]
    [bool] $Delete = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

$date = Get-Date
$AbandonedDevices
$Computers = Get-ADComputer -Filter * -Properties *
foreach($Computer in $Computers){

     $PasswordAge = New-TimeSpan -Start $_.PasswordLastSet -End $date
     if($PasswordAge -le $Days){
        $AbandonedDevices += $Computer
     }

}
$AbandonedDevices | Export-Csv 

