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
    [String] $UI_Date_Start
)

if ($Count -lt 0) {
    throw "Count cannot be negative!";
}

"Hello $OrganizationName ($OrganizationID; $OrganizationInitialDomainName)!. I was called by $CallerName."
