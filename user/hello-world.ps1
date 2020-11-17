param
(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [String] $UI_DeviceID,
    [Parameter(Mandatory = $false)]
    [bool] $myBool,
    [Parameter(Mandatory = $false)]
    [switch] $mySwitch
)

"Hello $UserName!. I was called by $CallerName."

"myBool: $myBool"
"mySwitch: $mySwitch"

"Will now sleep for 10 seconds"

1..10 | % { "Sleeping..."; Start-Sleep -Seconds 1; }

"Done sleeping! Bye."
