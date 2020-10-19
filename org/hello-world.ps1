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
    [int] $Number_Count,
    [Parameter(Mandatory = $false)]
    [String] $Date_StartDate
)

"Hello $OrganizationName ($OrganizationID; $OrganizationInitialDomainName)!. I was called by $CallerName."
