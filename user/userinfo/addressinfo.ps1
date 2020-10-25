param
(
    [Parameter(Mandatory=$false)]
    [Guid] $GitId = "B7A7B8DA-F861-42F6-8BC9-2DE255228025",
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
