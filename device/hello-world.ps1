param
(
    [Parameter(Mandatory = $true)]
    [String] $DeviceID,
    [Parameter(Mandatory = $true)]
    [String] $DeviceName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [String] $AADUser_ID,
)

"Hello $DeviceName ($DeviceID)!. I was called by $CallerName."