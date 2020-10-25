param
(
[Parameter(Mandatory=$false)]
    [Guid] $GitId = "E1A3717C-F838-45EB-B8F0-58A2D3333AB4",
    [Parameter(Mandatory = $true)]
    [String] $UserID,
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [String] $UI_GroupSecurityIdentifier,
    [Parameter(Mandatory = $false)]
    [String] $UI_GroupSecurityIdentifier_Something,
    [Parameter(Mandatory = $false)]
    [String] $UI_DeviceID
)

"Hello $UserName!. I was called by $CallerName."

"Will now sleep for 10 seconds"

1..10 | % { "Sleeping..."; Start-Sleep -Seconds 1; }

"Done sleeping! Bye."
