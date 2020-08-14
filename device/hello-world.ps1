param
(
    [Parameter(Mandatory = $true)]
    [String] $DeviceID,
    [Parameter(Mandatory = $true)]
    [String] $DeviceName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

"Hello $DeviceName ($DeviceID)!. I was called by $CallerName."