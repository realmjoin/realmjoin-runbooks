<#
    .SYNOPSIS
    This script collects information from all RealmJoin runbooks in a specified folder and generates a JSON file with the runbook details.

    .DESCRIPTION
    This script collects information from all RealmJoin runbooks in a specified folder and generates based on parameters several markdown kind of lists documents with the runbook details. The script can create the following documents:
    - A list of all runbooks with a short description. The created document also contains a table of contents and backlinks to the table of contents. In this document, the information regarding the following parameters are included: Category, Subcategory, Runbook Name, Synopsis, Description
    - A compact list of all runbooks with a short description. The created document does not contain a table of contents or other links. In the list, the columns are Category, Subcategory, Runbook Name and Synopsis
    - A list of permissions and RBAC roles for each runbook. In the list, the columns are Category, Subcategory, Runbook Name, Synopsis, Permissions and RBAC Roles.

    .PARAMETER includedScope
    The scope of the runbooks to include, which represents the root folder of the runbooks. The default value is "device", "group", "org", "user".

    .PARAMETER outputFolder
    The output folder for the generated markdown files or depending on the output mode for the generated folder structure. The default value is the folder "json", which is a subfolder of the folder "tools" (which is in default in the current folder).

    .PARAMETER rootFolder
    The root folder where the script should start to search for runbooks. The default value is the current location.

    .NOTES
    The script needs read/write access to the root folder and the output folder. The script will create the output folder if it does not exist.

#>


param(
    [string[]]$includedScope = @("device", "group", "org", "user"),
    [string]$outputFolder = $(Join-Path -Path (Join-Path -Path (Get-Location).Path -ChildPath "tools") -ChildPath "json"),
    [string]$rootFolder = (Get-Location).Path
)

######################################
#region Functions
######################################
function Get-RunbookBasics {
    param(
        [string]$runbookPath,
        [string]$relativeRunbookPath
    )

    if (Select-String -Path $runbookPath -Pattern '<#' -Quiet) {
        $runbookHelp = Get-Help $runbookPath -Full -ErrorAction SilentlyContinue
    }
    else {
        $runbookHelp = @{
            Synopsis    = $null
            Description = $null
            alertSet    = $null
            Parameters  = $null
        }
    }

    $TextInfo = (Get-Culture).TextInfo
    $runbookDisplayName = (Split-Path -LeafBase $runbookPath | ForEach-Object { $TextInfo.ToTitleCase($_) }) -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'
    $runbookDisplayPath = ($relativeRunbookPath -replace "\.ps1$", "") -replace "[\\/]", ' \ ' | ForEach-Object { $TextInfo.ToTitleCase($_) }
    $runbookDisplayPath = $runbookDisplayPath -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'


    return @{
        RunbookDisplayName = $runbookDisplayName
        RunbookDisplayPath = $runbookDisplayPath
        Synopsis           = $runbookHelp.Synopsis
        Description        = $runbookHelp.Description.Text
        Notes              = $runbookHelp.alertSet.alert.Text
        Parameters         = $runbookHelp.Parameters
    }
}

function Convert-PermissionJsonToMarkdown {
    param (
        [string]$JsonContent
    )

    $permissionsMarkdown = ""
    $rbacRolesMarkdown = ""
    $manualPermissionsMarkdown = ""

    $jsonObject = $JsonContent | ConvertFrom-Json

    foreach ($permission in $jsonObject.Permissions) {
        $permissionsMarkdown += "- **Type**: $($permission.Name)`n"
        foreach ($assignment in $permission.AppRoleAssignments) {
            $permissionsMarkdown += "  - $assignment`n"
        }
    }

    foreach ($role in $jsonObject.Roles) {
        $rbacRolesMarkdown += "- $role`n"
    }

    foreach ($manualPermission in $jsonObject.ManualPermissions) {
        $manualPermissionsMarkdown += "$manualPermission`n"
    }

    return @{
        Permissions = $permissionsMarkdown
        RBACRoles   = $rbacRolesMarkdown
        ManualPermissions = $manualPermissionsMarkdown
    }
}
#endregion

######################################
#region Collect runbook details
######################################

$runbookDescriptions = @()

Get-ChildItem -Path $rootFolder -Recurse -Include "*.ps1" -Exclude $MyInvocation.MyCommand.Name | Where-Object {
    $includedScope -contains $_.Directory.Parent.Name
} | ForEach-Object {
    $CurrentObject = $_

    $relativeRunbookPath = $CurrentObject.FullName -replace "^$rootFolder[\\/]*", ""
    $RelativeRunbookPath_PathOnly = Split-Path -Path $relativeRunbookPath
    $primaryFolder = ($RelativeRunbookPath_PathOnly -split "[\\/]" | Select-Object -First 1).Substring(0, 1).ToUpper() + ($RelativeRunbookPath_PathOnly -split "[\\/]" | Select-Object -First 1).Substring(1)
    $subFolder = ($RelativeRunbookPath_PathOnly -split "[\\/]" | Select-Object -Skip 1 | Select-Object -First 1).Substring(0, 1).ToUpper() + ($RelativeRunbookPath_PathOnly -split "[\\/]" | Select-Object -Skip 1 | Select-Object -First 1).Substring(1)

    # Get comment-based help content from the current runbook
    $CurrentRunbookBasics = Get-RunbookBasics -runbookPath $CurrentObject.FullName -relativeRunbookPath $relativeRunbookPath

    # Get additional content from .docs and .permissions files, if they exist. If they exist in the same folder as the runbook, they will be preferred.
    $docsPath_seperateFolder = Join-Path -Path $rootFolder -ChildPath ".docs\$RelativeRunbookPath_PathOnly\$($CurrentObject.BaseName).md"
    $docsPath_sameFolder = $($CurrentObject.FullName) -replace ".ps1", ".md"

    $docsPath = if (Test-Path -Path $docsPath_sameFolder) { $docsPath_sameFolder }
    elseif (Test-Path -Path $docsPath_seperateFolder) { $docsPath_seperateFolder }
    else { $null }

    $permissionsPath_seperateFolder = Join-Path -Path $rootFolder -ChildPath ".permissions\$RelativeRunbookPath_PathOnly\$($CurrentObject.BaseName).json"
    $permissionsPath_sameFolder = $($CurrentObject.FullName) -replace ".ps1", ".permissions.json"

    $permissionsPath = if (Test-Path -Path $permissionsPath_sameFolder) { $permissionsPath_sameFolder }
    elseif (Test-Path -Path $permissionsPath_seperateFolder) { $permissionsPath_seperateFolder }
    else { $null }

    $docsContent = if ($null -ne $docsPath) { Get-Content -Path $docsPath -Raw }
    $permissionsContent = if ($null -ne $permissionsPath) { Get-Content -Path $permissionsPath -Raw }
    $permissionsJSON = if ($null -ne $permissionsPath) { Get-Content -Path $permissionsPath -Raw | ConvertFrom-Json }

    $runbookDescriptions += [PSCustomObject]@{
        RunbookDisplayName           = $CurrentRunbookBasics.RunbookDisplayName
        RunbookDisplayPath           = $CurrentRunbookBasics.RunbookDisplayPath
        RelativeRunbookPath          = $relativeRunbookPath
        RelativeRunbookPath_PathOnly = $RelativeRunbookPath_PathOnly
        PrimaryFolder                = $primaryFolder
        SubFolder                    = $subFolder
        Synopsis                     = $CurrentRunbookBasics.Synopsis
        Description                  = $CurrentRunbookBasics.Description
        Notes                        = $CurrentRunbookBasics.Notes
        Parameters                   = $CurrentRunbookBasics.Parameters.parameter
        DocsContent                  = $docsContent
        PermissionsContent           = $permissionsContent
        PermissionsJson              = $permissionsJSON
    }
}

#endregion

######################################
#region Create JSON file
######################################

# Validate if the output folder exists
if (-not (Test-Path -Path $outputFolder)) {
    try {
        New-Item -Path $outputFolder -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Output folder is not existing and could not be created. Please create the folder manually and run the script again. Error: $_"
        exit 1
    }
}

# Validate if the output folder does not contain the file "RunbookDetails.json", if it does, remove it
if (Test-Path -Path (Join-Path -Path $outputFolder -ChildPath "RunbookDetails.json")) {
    try {
        Remove-Item -Path (Join-Path -Path $outputFolder -ChildPath "RunbookDetails.json") -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to remove existing RunbookDetails.json file. Error: $_"
        exit 1
    }
}

# Create the JSON file with the runbook details
$runbookDescriptions | ConvertTo-Json -Depth 15 | Set-Content -Path (Join-Path -Path $outputFolder -ChildPath "RunbookDetails.json")