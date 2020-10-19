param
(
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationName,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName,
    [Parameter(Mandatory = $false)]
    [int] $Count,
    [Parameter(Mandatory = $false)]
    [String] $Date_Start
)

"Hello $OrganizationName ($OrganizationID; $OrganizationInitialDomainName)!. I was called by $CallerName."
