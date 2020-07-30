param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationName,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

"Hello $OrganizationName ($OrganizationID; $OrganizationInitialDomainName)!. I was called by $CallerName."
