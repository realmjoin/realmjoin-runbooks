param
(
    [Parameter(Mandatory = $true)]
    [String] $UserID,
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [String] $AADGroup_SecurityIdentifier,
    [Parameter(Mandatory = $false)]
    [String] $AADDevice_ID
)

"Hello $UserName!. I was called by $CallerName."

"Will now sleep for 10 seconds"

1..10 | % { "Sleeping..."; Start-Sleep -Seconds 1; }

"Done sleeping! Bye."
