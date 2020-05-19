param
(
    [Parameter(Mandatory=$true)]
    [String] $Username,
    [Parameter(Mandatory=$true)]
    [String] $Callername
)

"Hello $Username!. I was called by $Callername"