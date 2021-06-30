#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param
(
    [string] $TestString1,
    [string] $TestString2,
    [string] $TestString3,
    [int] $TestInt,
    [double] $TestDouble,
    [datetime] $testDatetime,
    [bool] $TestBool,
    [switch] $TestSwitch,
    [object] $TestObject1,
    [object] $TestObject2
)

$PSBoundParameters | ConvertTo-Json
