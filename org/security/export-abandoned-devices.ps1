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

