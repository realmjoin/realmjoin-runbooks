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

"Output demo"

[Console]::Out.WriteLine("Test: stdout");
[Console]::Error.WriteLine("Test: stderr");

Write-Output "Test: Write-Output"
Write-Warning "Test: Write-Warning"
Write-Error "Test: Write-Error"
Write-Verbose "Test: Write-Verbose"
Write-Progress "Test: Write-Progress"
