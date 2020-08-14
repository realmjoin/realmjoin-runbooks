param
(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [Parameter(Mandatory = $true)]
    [String] $GroupName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

"Hello $GroupName ($GroupID)!. I was called by $CallerName."