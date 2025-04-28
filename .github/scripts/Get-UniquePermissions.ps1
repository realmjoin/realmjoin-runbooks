<#
.SYNOPSIS
    Collects and deduplicates permissions from JSON files within a specified directory.

.DESCRIPTION
    This script scans a specified directory for JSON files containing permissions and roles. It collects and deduplicates the permissions, merges role assignments, and exports the results to JSON files in an output directory.

.PARAMETER RootFolder
    The root directory which is used to resolve relative paths. Defaults to the current directory.
    If the parameter permissionsPath is not specified, the script will look for the permission file to the runbook in the same folder as the runbook with the same name and the extension ".permissions.json".
    Then this path would be used to collect the permission files next to the runbook files.
    The default value is the current directory.

.PARAMETER permissionsPath
    The Path of the folder containing the permissions JSON files. Could be for example "./.permissions" in the root folder.
    If not specified, the script will look for the permission file to the runbook in the same folder as the runbook with the same name and the extension ".permissions.json".

.PARAMETER bothPathCombinations
    If defined, also permissionPath has to be defined. If true, the script will collect the permissions from the permissionsPath (just *.json) and the rootFolder (*.permissions.json) and merge them.
    The default value is false.

.PARAMETER OutputFolderName
    The name of the folder where the processed permissions and roles will be saved. Defaults to "UniquePermissions" in the current directory.

.PARAMETER OutputFileNamePrefix
    The prefix for the output files. Defaults to "RealmJoinRunbook_collected_".

.PARAMETER includedRunbooks
    A semicolon-separated string of relative paths to filter the JSON files. If empty, all JSON files in the permissions folder will be processed.
    Example: "org/general/add-user;user/phone/get-teams-user-info"

.PARAMETER includedScope
    The scope of the permissions to be collected. If empty, all permissions will be collected.
    An example Value which would filder the permissions to only device and user permissions: @("device", "user")

.NOTES
    The script normalizes paths to use forward slashes and trims the root path from the JSON file paths for comparison with the relative paths.

    The script creates the output folder if it does not exist and writes the collected permissions and roles to JSON files in the output folder.

#>
param(
    [Parameter(Mandatory=$true)]
    [string]$rootFolder = (Get-Location).Path,
    [string]$permissionsFolderName,
    [ValidateScript({
        if ($bothPathCombinations -and -not $permissionsFolderName) {
            throw "bothPathCombinations can only be selected if permissionsFolderName is also defined."
        }
        $true
    })]
    [switch]$bothPathCombinations,
    [string]$outputFolder = (Join-Path -Path ((Get-Location).Path) -ChildPath "UniquePermissions"),
    [string]$OutputFileNamePrefix = "RealmJoinRunbook_collected_",
    [string]$includedRunbooks,
    [string[]]$includedScope = @("device", "group", "org", "user")
)

# Initialize the collections
$RawPermissions = @()
$CollectedRoles = @()

# Initialize the $JsonFiles array
$JsonFiles = @()

# Get all .json files in the permissions path recursively
if($bothPathCombinations) {
    $JsonFiles = @($JsonFiles + (Get-ChildItem -Path $rootFolder -Filter *.permissions.json -Recurse | Where-Object { $includedScope -contains $_.Directory.Parent.Name }))
    $JsonFiles = @($JsonFiles + (Get-ChildItem -Path $permissionsPath -Filter *.json -Recurse | Where-Object { $includedScope -contains $_.Directory.Parent.Name }))
} else {
    if($permissionsFolderName -eq $null -or $permissionsFolderName -like "") {
        $JsonFiles = Get-ChildItem -Path $rootFolder -Filter *.permissions.json -Recurse | Where-Object { $includedScope -contains $_.Directory.Parent.Name }
    } else {
        $JsonFiles = Get-ChildItem -Path $permissionsPath -Filter *.json -Recurse | Where-Object { $includedScope -contains $_.Directory.Parent.Name }
    }
}

if($includedRunbooks -eq $null -or $includedRunbooks -like "") {
    Write-Output "No runbooks specified. All JSON files in the permissions folder will be processed."
    $RelativePathArray = $null
} else {
    Write-Output "Runbooks only specified runbooks will be processed."
    # Convert the semicolon-separated string into an array and normalize the paths.
    $RelativePathArray = @()
    $RelativePathArray = $includedRunbooks -split ';' | ForEach-Object { $_ -replace '\\', '/' }
}


foreach ($JsonFile in $JsonFiles) {
    $PermissionsContent = Get-Content -Path $JsonFile.FullName | ConvertFrom-Json

    # Normalize the path of the JSON file
    $NormalizedJsonFilePath = $JsonFile.FullName -replace '\\', '/' -replace [regex]::Escape($rootFolder), ''

    # Check if the file belongs to the specified relative paths
    if ($null -eq $RelativePathArray -or $RelativePathArray -contains $NormalizedJsonFilePath.TrimStart('/')) {
        # Add the permissions to the collections
        $RawPermissions += $PermissionsContent.Permissions
        if ($null -ne $PermissionsContent.Roles -or $PermissionsContent.Roles -ne "") {
            $CollectedRoles += $PermissionsContent.Roles
        }
    }
}

# Initialize a hashtable to store the unique permissions
$UniquePermissions = @{}

# Iterate over the RawPermissions array
foreach ($Permission in $RawPermissions) {
    # Use the Name and Id as the key
    $Key = "$($Permission.name)-$($Permission.Id)"

    # If the key does not exist in the hashtable, add it
    if (-not $UniquePermissions.ContainsKey($Key)) {
        $UniquePermissions[$Key] = $Permission
    }
    else {
        # If the key exists, merge the AppRoleAssignments
        $UniquePermissions[$Key].AppRoleAssignments = $UniquePermissions[$Key].AppRoleAssignments + $Permission.AppRoleAssignments | Sort-Object | Get-Unique
    }
}

# Convert the hashtable values to an array
$DeduplicatedPermissions = $UniquePermissions.Values

# Export permission/roles files
$PermissionExport = $DeduplicatedPermissions | ConvertTo-Json -Depth 10
$RoleExport = $CollectedRoles | Get-Unique | ConvertTo-Json -Depth 10
$PermissionFileName = "$($OutputFileNamePrefix)permissions.json"
$RoleFileName = "$($OutputFileNamePrefix)rbacroles.json"

# Create the output folder if it does not exist
if (-not (Test-Path -Path $outputFolder)) {
    try {
        New-Item -Path $outputFolder -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Output "Created output folder: $outputFolder"
    } catch {
        Write-Error "Output folder does not exist and could not be created: $outputFolder - Error: $_"
        exit 1
    }
}

Write-Output "Exporting permissions to: $outputFolder"
$PermissionExport | Out-File -FilePath $(Join-Path -Path $outputFolder -ChildPath $PermissionFileName)
$RoleExport | Out-File -FilePath $(Join-Path -Path $outputFolder -ChildPath $RoleFileName)