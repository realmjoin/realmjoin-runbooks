param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

"Hello $OrganizationName ($OrganizationID)!. I was called by $CallerName."
