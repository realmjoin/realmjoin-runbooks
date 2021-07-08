<#
  .SYNOPSIS
  Parameter testing only

  .DESCRIPTION
  Provides some tests on how different types of parameters are 
  being passed to the PowerShell runbook scripts.
#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

[CmdletBinding(DefaultParameterSetName = 'Path')]
param
(
    [string] $TestStringPlain,
    [string] $TestStringWithDefault = "asdf",
    [Parameter(Mandatory)]
    [string] $TestStringMandatoryAndDefault = "asdf",
    [ValidateSet("Chocolate", "Strawberry", "Vanilla")]
    [string] $TestStringValidateSet,
    [int] $TestInt,
    [double] $TestDouble,
    [datetime] $TestDateTime,
    [DateTimeOffset] $TestDateTimeOffset,
    [ValidateScript( { Use-RJInterface -Date } )]
    $TestDate,
    [ValidateScript( { Use-RJInterface -Time } )]
    $TestTime,
    [bool] $TestBool,
    [bool] $TestBoolWithDefaultTrue = $true,
    [switch] $TestSwitch,
    [switch] $TestSwitchWithDefaultPresent = [switch]::Present,
    [switch] $TestSwitchWithDefaultTrue = $true,
    [object] $TestObject1,
    [object] $TestObject2,
    $TestNoType
)

$PSBoundParameters | ConvertTo-Json

if ($TestDateTime) { "`$TestDatetime: $($TestDateTime.ToString("o")), $($TestDateTime.Kind)" }
if ($TestDateTimeOffset) { "`$TestDateTimeOffset: $($TestDateTimeOffset.ToString("o")), $($TestDateTimeOffset.Offset)" }
