<#
  .SYNOPSIS
  List expiry date of all AppRegistration (Service Principal) credentials

  .DESCRIPTION
  List expiry date of all AppRegistration (Service Principal) credentials

  .NOTES
  Permissions: 

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

Connect-RjRbGraph

$apps = Invoke-RjRbRestMethodGraph -Resource "/applications" -FollowPaging

$date = Get-Date

$apps | ForEach-Object {
  if (($_.keyCredentials) -or ($_.passwordCredentials)) {
    "## App DisplayName: $($_.displayName)"
    "## App Id: $($_.appId)"
    ""
    $_.keyCredentials | ForEach-Object {
      "Cert DisplayName: $($_.displayName)"
      "Cert ID: $($_.keyId)"
      #"Cert EndDateTime: $($_.endDateTime)"
      $enddate=[datetime]$_.endDateTime
      "Days left: $((New-TimeSpan -Start $date -End $enddate).days)"
      ""
    }
    $_.passwordCredentials | ForEach-Object {
      "Client Secret DisplayName: $($_.displayName)"
      "Client Secret ID: $($_.keyId)"
      #"Client Secret EndDateTime: $($_.endDateTime)"
      $enddate=[datetime]$_.endDateTime
      "Days left: $((New-TimeSpan -Start $date -End $enddate).days)"
      ""
    }
  }
}