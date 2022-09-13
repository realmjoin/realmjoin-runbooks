<#
  .SYNOPSIS
  List Room configuration.

  .DESCRIPTION
  List Room configuration.

  .NOTES
  Permissions
  MS Graph (API):
  - Place.Read.All

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

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox"} )]
    [string] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$($UserName)" 
Invoke-RjRbRestMethodGraph -Resource "/places/$($User.userPrincipalName)/microsoft.graph.room" 