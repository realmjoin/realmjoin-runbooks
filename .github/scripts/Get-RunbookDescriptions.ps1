<#
    .SYNOPSIS
    This script collects information from all RealmJoin runbooks in a specified folder and generates based on parameters one or several markdown files with the runbook details.

    .DESCRIPTION
    This script collects information from all RealmJoin runbooks in a specified folder and generates based on parameters one or several markdown files with the runbook details.
    The script can generate a single markdown file with all runbook details, a single markdown file with a TOC and separate markdown files for each primary folder, or separate markdown files for each primary and subfolder.

    .PARAMETER includedScope
    The scope of the runbooks to include, which represents the root folder of the runbooks. The default value is "device", "group", "org", "user".

    .PARAMETER includePermissions
    If specified, the script will include permissions information in the output. These permissions has to be provided in a .json file with the same name as the runbook in a .permissions folder.

    .PARAMETER includeDocs
    If specified, the script will include documentation information in the output. These documentation has to be provided in a .md file with the same name as the runbook in a .docs folder.

    .PARAMETER includeWhereToFind
    If specified, the script will include information about where to find the runbook in the output. This information is taken from the relative path of the runbook.

    .PARAMETER includeNotes
    If specified, the script will include notes information in the output. These notes will be taken from the comment-based help of the runbook.

    .PARAMETER includeParameters
    If specified, the script will include parameter information in the output. Note that if the switch is activated, the output can become significantly more comprehensive,
    which should be taken into consideration especially in ‘OneFile mode’ (see outputMode). The default value is $false.

    .PARAMETER includeAdditionalLinks
    If specified, the script will include additional links in the output. The default value is $false.

    .PARAMETER outputMode
    The output mode for the generated markdown files. The default value is "OneFile".
    - "OneFile": Generates a single markdown file with all runbook details.
    - "SeparateFileSeparateFolder": Generates a folder structure with root folders (for example, org) and subfolders (for example, general) and separate markdown files for each runbook.

    .PARAMETER nameTOCFilesAlwaysREADME
    Only relevant in "SeparateFileSeparateFolder" output mode. Otherwise, the value is ignored.
    If specified, the script will always name the overview files for the scope folders "README.md". Otherwise the name would be generated based on the folder name - for example, "org-overview.md"

    .PARAMETER mainOutfile
    The name of the main output file. The default value is "RealmJoin-RunbookOverview.md".
    In "SeparateFileSeparateFolder" output mode, the main output file will contain the TOC.

    .PARAMETER outputFolder
    The output folder for the generated markdown files or depending on the output mode for the generated folder structure. The default value is the folder "docs" in the current location.

    .PARAMETER rootFolder
    The root folder where the script should start to search for runbooks. The default value is the current location.

    .NOTES
    The script needs read/write access to the root folder and the output folder. The script will create the output folder if it does not exist.

#>


param(
    [string[]]$includedScope = @("device", "group", "org", "user"),
    [switch]$includePermissions,
    [switch]$includeDocs,
    [switch]$includeWhereToFind,
    [switch]$includeNotes,
    [switch]$includeParameters,
    [switch]$includeAdditionalLinks,
    [ValidateSet("OneFile", "SeparateFileSeparateFolder")]
    [string]$outputMode = "OneFile",
    [switch]$nameTOCFilesAlwaysREADME,
    [string]$mainOutfile = "RealmJoin-RunbookOverview.md",
    [string]$outputFolder = $(Join-Path -Path (Get-Location).Path -ChildPath "docs"),
    [string]$rootFolder = (Get-Location).Path
)

######################################
#region Open issues
#- The region Static Parameters is currently used for development purposes. This should be removed in the future.
#- Missing comment-based help in the runbooks is not handled correctly (see org/mail/set-booking-config.ps1)
#    - Added simple check if file starts with <# and if not, the help content is set to $null -> not the best solution, I guess
#- If adding content from .docs, the header level could not be adjusted to the current level. So it could be that the header level is one level too high.

#endregion

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
        $global:MissingRunbookHelp += $runbookPath
    }

    $TextInfo = (Get-Culture).TextInfo
    $runbookBaseName = Split-Path -LeafBase $runbookPath

    # Keep original file name for file creation (with _scheduled)
    $runbookFileName = ($runbookBaseName | ForEach-Object { $TextInfo.ToTitleCase($_) }) -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'

    # Check if the runbook ends with _scheduled
    $isScheduled = $runbookBaseName -match '_scheduled$'
    if ($isScheduled) {
        # Remove _scheduled suffix for display name only
        $runbookBaseName = $runbookBaseName -replace '_scheduled$', ''
    }

    $runbookDisplayName = ($runbookBaseName | ForEach-Object { $TextInfo.ToTitleCase($_) }) -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'

    # Ensure acronyms are uppercase
    $runbookDisplayName = $runbookDisplayName -replace '\bAvd\b', 'AVD' -replace '\bMdm\b', 'MDM'

    # Add (Scheduled) suffix if it was a scheduled runbook
    if ($isScheduled) {
        $runbookDisplayName = $runbookDisplayName + " (Scheduled)"
    }

    $runbookDisplayPath = ($relativeRunbookPath -replace "\.ps1$", "") -replace "[\\/]", ' \ ' | ForEach-Object { $TextInfo.ToTitleCase($_) }
    $runbookDisplayPath = $runbookDisplayPath -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'
    # Ensure acronyms are uppercase in path too
    $runbookDisplayPath = $runbookDisplayPath -replace '\bAvd\b', 'AVD' -replace '\bMdm\b', 'MDM'


    return @{
        RunbookDisplayName = $runbookDisplayName
        RunbookFileName    = $runbookFileName
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
        Permissions       = $permissionsMarkdown
        RBACRoles         = $rbacRolesMarkdown
        ManualPermissions = $manualPermissionsMarkdown
    }
}
#endregion

######################################
#region Static Parameters
######################################

# # Parameters for development - should be removed in the future
# $includedScope = @("device", "group", "org", "user")
# $includePermissions = $true
# $includeParameters = $false
# $includeDocs = $true
# $includeNotes = $true
# # "OneFile", "SeparateFileSeparateFolder"
# $outputMode = "OneFile"
# $mainOutfile = "RealmJoin-RunbookOverview.md"
# $ListOverviewFile = "RealmJoin-RunbookList.md"
# $outputFolder = Join-Path -Path (Get-Location).Path -ChildPath ".ProcessedDocs-$($outputMode)"
# $rootFolder = (Get-Location).Path

# Global variable to collect runbooks without comment-based help
$global:MissingRunbookHelp = @()

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
    $docsPath_separateFolder = Join-Path -Path $rootFolder -ChildPath ".docs\$RelativeRunbookPath_PathOnly\$($CurrentObject.BaseName).md"
    $docsPath_sameFolder = $($CurrentObject.FullName) -replace ".ps1", ".md"

    $docsPath = if (Test-Path -Path $docsPath_sameFolder) { $docsPath_sameFolder }
    elseif (Test-Path -Path $docsPath_separateFolder) { $docsPath_separateFolder }
    else { $null }

    $permissionsPath_separateFolder = Join-Path -Path $rootFolder -ChildPath ".permissions\$RelativeRunbookPath_PathOnly\$($CurrentObject.BaseName).json"
    $permissionsPath_sameFolder = $($CurrentObject.FullName) -replace ".ps1", ".permissions.json"

    $permissionsPath = if (Test-Path -Path $permissionsPath_sameFolder) { $permissionsPath_sameFolder }
    elseif (Test-Path -Path $permissionsPath_separateFolder) { $permissionsPath_separateFolder }
    else { $null }

    $docsContent = if ($null -ne $docsPath) { Get-Content -Path $docsPath -Raw }
    $permissionsContent = if ($null -ne $permissionsPath) { Get-Content -Path $permissionsPath -Raw }

    $runbookDescriptions += [PSCustomObject]@{
        RunbookDisplayName           = $CurrentRunbookBasics.RunbookDisplayName
        RunbookFileName              = $CurrentRunbookBasics.RunbookFileName
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
    }
}

#endregion
######################################
#region Prepare variables
######################################

# mainOutfile - check if the file name contains a file extension .md (case-insensitive)
if ($mainOutfile -notmatch "\.md$") {
    $mainOutfile += ".md"
}

# mainOutfile - check if the file name is README.md otherwise normalize the file name
if ($mainOutfile -notlike "README.md") {
    $mainOutfile = ($mainOutfile -replace ' ', '-').ToLower()
}

# Calculate relative path from rootFolder to outputFolder for links
$relativeOutputPath = [System.IO.Path]::GetRelativePath($rootFolder, $outputFolder)
# Replace backslashes with forward slashes for URLs
$relativeOutputPath = $relativeOutputPath.Replace('\', '/')
# Ensure path ends with a slash
if (-not $relativeOutputPath.EndsWith('/')) {
    $relativeOutputPath += '/'
}

######################################
#region Output
######################################

if (-not (Test-Path -Path $outputFolder)) {
    try {
        New-Item -Path $outputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Output folder created: $outputFolder"
    }
    catch {
        Write-Error "Failed to create output folder: $_"
        exit 1
    }
}

if ($outputMode -eq "OneFile") {
    ################################################################################################
    #region OneFile
    ################################################################################################
    $ResultFile = Join-Path -Path $outputFolder -ChildPath ($mainOutfile)
    if (Test-Path -Path $ResultFile) {
        Remove-Item -Path $ResultFile -Force -ErrorAction SilentlyContinue
    }

    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder

    Add-Content -Path $ResultFile -Value "<a name='runbook-overview'></a>"
    Add-Content -Path $ResultFile -Value "# RealmJoin runbook overview"
    Add-Content -Path $ResultFile -Value "This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality."
    Add-Content -Path $ResultFile -Value ""
    Add-Content -Path $ResultFile -Value "To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:"
    foreach ($scope in $includedScope) {
        Add-Content -Path $ResultFile -Value "- $scope"
    }
    Add-Content -Path $ResultFile -Value ""
    Add-Content -Path $ResultFile -Value "Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory."
    Add-Content -Path $ResultFile -Value ""

    # Create TOC
    Add-Content -Path $ResultFile -Value "# Runbooks - Table of contents"
    Add-Content -Path $ResultFile -Value ""

    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$primaryFolderAnchor-$(($subFolder -replace ' ', '-').ToLower())"

        if ($lastPrimaryFolder -ne $primaryFolder) {
            Add-Content -Path $ResultFile -Value "- [$primaryFolder](#$primaryFolderAnchor)"
            $lastPrimaryFolder = $primaryFolder
        }

        Add-Content -Path $ResultFile -Value "  - [$subFolder](#$subFolderAnchor)"


        foreach ($runbook in $primaryGroup.Group) {
            $runbookAnchor = "$subFolderAnchor-$(($runbook.RunbookDisplayName -replace ' ', '-').ToLower())"
            Add-Content -Path $ResultFile -Value "      - [$($runbook.RunbookDisplayName)](#$(($runbook.RunbookDisplayName -replace ' ', '-').ToLower()))"
        }
    }

    Add-Content -Path $ResultFile -Value ""

    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$primaryFolderAnchor-$(($subFolder -replace ' ', '-').ToLower())"

        Add-Content -Path $ResultFile -Value "<a name='$primaryFolderAnchor'></a>"
        Add-Content -Path $ResultFile -Value ""
        Add-Content -Path $ResultFile -Value "# $primaryFolder"
        Add-Content -Path $ResultFile -Value "<a name='$subFolderAnchor'></a>"
        Add-Content -Path $ResultFile -Value ""
        Add-Content -Path $ResultFile -Value "## $subFolder"


        foreach ($runbook in $primaryGroup.Group) {
            $runbookAnchor = "$subFolderAnchor-$(($runbook.RunbookDisplayName -replace ' ', '-').ToLower())"

            Add-Content -Path $ResultFile -Value "<a name='$runbookAnchor'></a>"
            Add-Content -Path $ResultFile -Value ""
            Add-Content -Path $ResultFile -Value "### $($runbook.RunbookDisplayName)"

            if ($runbook.Synopsis) {
                Add-Content -Path $ResultFile -Value "#### $($runbook.Synopsis)"
                Add-Content -Path $ResultFile -Value ""
            }
            if ($runbook.Description) {
                Add-Content -Path $ResultFile -Value "#### Description"
                Add-Content -Path $ResultFile -Value $runbook.Description
                Add-Content -Path $ResultFile -Value ""
            }

            if ($includeWhereToFind) {
                Add-Content -Path $ResultFile -Value "#### Where to find"
                Add-Content -Path $ResultFile -Value $runbook.RunbookDisplayPath
                Add-Content -Path $ResultFile -Value ""
            }

            if ($includeDocs) {
                if ($runbook.DocsContent) {
                    Add-Content -Path $ResultFile -Value $runbook.DocsContent
                    Add-Content -Path $ResultFile -Value ""
                }
            }

            if ($includeNotes) {
                if ($runbook.Notes) {
                    Add-Content -Path $ResultFile -Value "#### Notes"
                    Add-Content -Path $ResultFile -Value $runbook.Notes
                    Add-Content -Path $ResultFile -Value ""
                }
            }

            if ($includePermissions) {
                if ($runbook.PermissionsContent) {
                    $RunbookPermissions = Convert-PermissionJsonToMarkdown -JsonContent $runbook.PermissionsContent
                    # Solange in $RunbookPermissions bzw. in einer der Properties ein Wert vorhanden ist, wird der Abschnitt ausgegeben
                    if (($RunbookPermissions.Permissions) -or ($RunbookPermissions.RBACRoles) -or ($RunbookPermissions.ManualPermissions)) {
                        Add-Content -Path $ResultFile -Value "#### Permissions"
                        if ($RunbookPermissions.Permissions) {
                            Add-Content -Path $ResultFile -Value "##### Application permissions"
                            Add-Content -Path $ResultFile -Value $RunbookPermissions.Permissions
                        }
                        if ($RunbookPermissions.ManualPermissions) {
                            Add-Content -Path $ResultFile -Value "##### Permission notes"
                            Add-Content -Path $ResultFile -Value $RunbookPermissions.ManualPermissions
                        }
                        if ($RunbookPermissions.RBACRoles) {
                            Add-Content -Path $ResultFile -Value "##### RBAC roles"
                            Add-Content -Path $ResultFile -Value $RunbookPermissions.RBACRoles
                        }
                    }

                }
            }

            if ($includeParameters) {
                if ($runbook.Parameters) {
                    Add-Content -Path $ResultFile -Value "#### Parameters"
                    foreach ($parameter in $runbook.Parameters) {
                        Add-Content -Path $ResultFile -Value "##### $($parameter.Name)"
                        # Filter out ValidateScript blocks from description
                        $paramDescription = if ($parameter.Description) {
                            $desc = ($parameter.Description.Text -join " ").Trim()
                            # Remove ValidateScript blocks
                            $desc = $desc -replace '\[ValidateScript\([^\]]+\)\]', ''
                            $desc.Trim()
                        } else { "" }
                        if ($paramDescription) {
                            Add-Content -Path $ResultFile -Value $paramDescription
                        }
                        Add-Content -Path $ResultFile -Value ""
                        # Format type for display
                        $paramType = if ($parameter.type.name) {
                            if ($parameter.type.name -eq 'String[]') {
                                "String Array"
                            } else {
                                $parameter.type.name
                            }
                        } else { "" }
                        Add-Content -Path $ResultFile -Value "| Property | Value |"
                        Add-Content -Path $ResultFile -Value "|----------|-------|"
                        Add-Content -Path $ResultFile -Value "| Default Value | $($parameter.DefaultValue) |"
                        Add-Content -Path $ResultFile -Value "| Required | $($parameter.Required) |"
                        Add-Content -Path $ResultFile -Value "| Type | $paramType |"
                        Add-Content -Path $ResultFile -Value ""
                    }
                }
            }
            Add-Content -Path $ResultFile -Value ""
            Add-Content -Path $ResultFile -Value "[Back to Table of Content](#table-of-contents)"
            Add-Content -Path $ResultFile -Value "`n `n `n"
        }
    }
    #endregion
}
elseif ($outputMode -eq "SeparateFileSeparateFolder") {
    ################################################################################################
    #region SeparateFileSeparateFolder
    ################################################################################################
    $ResultFile = Join-Path -Path $rootFolder -ChildPath ($mainOutfile)
    if (Test-Path -Path $ResultFile) {
        Remove-Item -Path $ResultFile -Force -ErrorAction SilentlyContinue
    }


    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder | Sort-Object -Property Name

    # General information regarding the RealmJoin runbook repository
    Add-Content -Path $ResultFile -Value "# RealmJoin runbook repository"
    Add-Content -Path $ResultFile -Value "This repository contains all runbooks for the RealmJoin portal. The runbooks are organized into different folders based on their area of application."
    Add-Content -Path $ResultFile -Value "The following categories are currently available:"
    foreach ($scope in $includedScope) {
        Add-Content -Path $ResultFile -Value "- $scope"
    }
    Add-Content -Path $ResultFile -Value ""
    Add-Content -Path $ResultFile -Value "Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory."

    # Runbook overview part
    Add-Content -Path $ResultFile -Value "<a name='runbook-overview'></a>"
    Add-Content -Path $ResultFile -Value "# RealmJoin runbook overview"
    Add-Content -Path $ResultFile -Value "In the following, each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality."
    Add-Content -Path $ResultFile -Value "Also the document for each runbook contains information about permissions, where to find, notes, and parameters and further information in general."
    Add-Content -Path $ResultFile -Value ""

    if ($includeAdditionalLinks) {
        Add-Content -Path $ResultFile -Value ""
        Add-Content -Path $ResultFile -Value "## Additional information"
        Add-Content -Path $ResultFile -Value "Apart from the following runbook descriptions, further content such as runbook overview lists or permission summaries can be found here:"
        Add-Content -Path $ResultFile -Value "- [General runbook information and setup guides]($($relativeOutputPath)general)"
        Add-Content -Path $ResultFile -Value "- [List based content]($($relativeOutputPath)lists)"
        Add-Content -Path $ResultFile -Value "- [JSON based content]($($relativeOutputPath)other/json)"
        Add-Content -Path $ResultFile -Value "- [Other content]($($relativeOutputPath)other)"
        Add-Content -Path $ResultFile -Value ""
    }


    # Create TOC in the main result file
    Add-Content -Path $ResultFile -Value "## Table of contents"
    Add-Content -Path $ResultFile -Value ""

    # Initialize Array to collect all primaryFolderOverviewFiles
    $primaryFolderOverviewFiles = @()

    # First, collect all unique primary folders in alphabetical order
    $uniquePrimaryFolders = @()
    foreach ($group in $groupedRunbooks) {
        $primaryFolder = $group.Name.Split(',')[0].Trim()
        if ($uniquePrimaryFolders -notcontains $primaryFolder) {
            $uniquePrimaryFolders += $primaryFolder
        }
    }
    $uniquePrimaryFolders = $uniquePrimaryFolders | Sort-Object

    # Process primary folders in alphabetical order
    foreach ($primaryFolder in $uniquePrimaryFolders) {
        $primaryFolderLink = ($primaryFolder -replace ' ', '-').ToLower()

        # Add primary folder to main TOC
        if ($nameTOCFilesAlwaysREADME) {
            Add-Content -Path $ResultFile -Value "- [$primaryFolder]($($relativeOutputPath)$primaryFolderLink/README.md)"
        }
        else {
            Add-Content -Path $ResultFile -Value "- [$primaryFolder]($($relativeOutputPath)$primaryFolderLink/$primaryFolderLink-overview.md)"
        }

        # Create TOC for each primary folder
        $primaryFolderPath = Join-Path -Path $outputFolder -ChildPath $primaryFolderLink
        if (-not (Test-Path -Path $primaryFolderPath)) {
            New-Item -Path $primaryFolderPath -ItemType Directory -Force | Out-Null
        }
        if ($nameTOCFilesAlwaysREADME) {
            $primaryFolderOverviewFile = Join-Path -Path $primaryFolderPath -ChildPath "README.md"
        }
        else {
            $primaryFolderOverviewFile = Join-Path -Path $primaryFolderPath -ChildPath "$primaryFolderLink-overview.md"
        }

        # Collect each primaryFolderOverviewFile in an array
        $primaryFolderOverviewFiles += $primaryFolderOverviewFile

        Remove-Item -Path $primaryFolderOverviewFile -Force -ErrorAction SilentlyContinue
        Add-Content -Path $primaryFolderOverviewFile -Value "# $primaryFolder Overview"
        Add-Content -Path $primaryFolderOverviewFile -Value ""

        # Get all subfolders for this primary folder and sort them
        $subFolders = $groupedRunbooks | Where-Object { $_.Name.Split(',')[0].Trim() -eq $primaryFolder } |
        ForEach-Object { $_.Name.Split(',')[1].Trim() } | Sort-Object -Unique

        # Process each subfolder
        foreach ($subFolder in $subFolders) {
            $subFolderLink = "$primaryFolderLink-$(($subFolder -replace ' ', '-').ToLower())"

            if ($nameTOCFilesAlwaysREADME) {
                Add-Content -Path $ResultFile -Value "  - [$subFolder]($($relativeOutputPath)$primaryFolderLink/README.md#$subFolderLink)"
            }
            else {
                Add-Content -Path $ResultFile -Value "  - [$subFolder]($($relativeOutputPath)$primaryFolderLink/$primaryFolderLink-overview.md#$subFolderLink)"
            }
            Add-Content -Path $primaryFolderOverviewFile -Value "<a name='$subFolderLink'></a>"
            Add-Content -Path $ResultFile -Value ""
            Add-Content -Path $primaryFolderOverviewFile -Value "## $subFolder"

            # Get and sort runbooks for this primary folder and subfolder
            $runbooks = $groupedRunbooks |
            Where-Object { $_.Name -eq "$primaryFolder, $subFolder" } |
            Select-Object -ExpandProperty Group |
            Sort-Object -Property RunbookDisplayName

            foreach ($runbook in $runbooks) {
                $runbookFileName = ($runbook.RunbookFileName -replace ' ', '-').ToLower() + ".md"
                $runbookFilePath = Join-Path -Path $outputFolder -ChildPath "$primaryFolderLink\$(($subFolder -replace ' ', '-').ToLower())\$runbookFileName"
                $runbookAnchor = "$subFolderLink-$(($runbook.RunbookDisplayName -replace ' ', '-').ToLower())"

                # Ensure the directory exists
                $runbookDirectory = Split-Path -Path $runbookFilePath -Parent
                if (-not (Test-Path -Path $runbookDirectory)) {
                    New-Item -Path $runbookDirectory -ItemType Directory -Force | Out-Null
                }

                # Add link to the runbook file in the main TOC
                Add-Content -Path $ResultFile -Value "    - [$($runbook.RunbookDisplayName)]($($relativeOutputPath)$primaryFolderLink/$(($subFolder -replace ' ', '-').ToLower())/$runbookFileName)"
                # Add link to the runbook file in the primary folder TOC
                Add-Content -Path $primaryFolderOverviewFile -Value "  - [$($runbook.RunbookDisplayName)]($(($subFolder -replace ' ', '-').ToLower())/$runbookFileName)"

                # Create individual file for each runbook
                Remove-Item -Path $runbookFilePath -Force -ErrorAction SilentlyContinue
                Add-Content -Path $runbookFilePath -Value "# $($runbook.RunbookDisplayName)"
                Add-Content -Path $runbookFilePath -Value ""

                if ($runbook.Synopsis) {
                    Add-Content -Path $runbookFilePath -Value "$($runbook.Synopsis)"
                    Add-Content -Path $runbookFilePath -Value ""
                }
                if ($runbook.Description) {
                    Add-Content -Path $runbookFilePath -Value "## Detailed description"
                    Add-Content -Path $runbookFilePath -Value $runbook.Description
                    Add-Content -Path $runbookFilePath -Value ""
                }
                if ($includeWhereToFind) {
                    Add-Content -Path $runbookFilePath -Value "## Where to find"
                    Add-Content -Path $runbookFilePath -Value $runbook.RunbookDisplayPath
                    Add-Content -Path $runbookFilePath -Value ""
                }
                if ($includeDocs) {
                    if ($runbook.DocsContent) {
                        Add-Content -Path $runbookFilePath -Value $runbook.DocsContent
                        Add-Content -Path $runbookFilePath -Value ""
                    }
                }
                if ($includeNotes) {
                    if ($runbook.Notes) {
                        Add-Content -Path $runbookFilePath -Value "## Notes"
                        Add-Content -Path $runbookFilePath -Value $runbook.Notes
                        Add-Content -Path $runbookFilePath -Value ""
                    }
                }
                if ($includePermissions) {
                    if ($runbook.PermissionsContent) {
                        $RunbookPermissions = Convert-PermissionJsonToMarkdown -JsonContent $runbook.PermissionsContent
                        if (($RunbookPermissions.Permissions) -or ($RunbookPermissions.RBACRoles) -or ($RunbookPermissions.ManualPermissions)) {
                            Add-Content -Path $runbookFilePath -Value "## Permissions"
                            if ($RunbookPermissions.Permissions) {
                                Add-Content -Path $runbookFilePath -Value "### Application permissions"
                                Add-Content -Path $runbookFilePath -Value $RunbookPermissions.Permissions
                            }
                            if ($RunbookPermissions.ManualPermissions) {
                                Add-Content -Path $runbookFilePath -Value "### Permission notes"
                                Add-Content -Path $runbookFilePath -Value $RunbookPermissions.ManualPermissions
                            }
                            if ($RunbookPermissions.RBACRoles) {
                                Add-Content -Path $runbookFilePath -Value "### RBAC roles"
                                Add-Content -Path $runbookFilePath -Value $RunbookPermissions.RBACRoles
                            }
                            Add-Content -Path $runbookFilePath -Value ""
                        }
                    }
                }

                if ($includeParameters) {
                    if ($runbook.Parameters) {
                        Add-Content -Path $runbookFilePath -Value "## Parameters"
                        foreach ($parameter in $runbook.Parameters) {
                            if ($parameter.Name -notlike "CallerName") {
                                Add-Content -Path $runbookFilePath -Value "### $($parameter.Name)"
                                # Filter out ValidateScript blocks from description
                                $paramDescription = if ($parameter.Description) {
                                    $desc = ($parameter.Description.Text -join " ").Trim()
                                    # Remove ValidateScript blocks
                                    $desc = $desc -replace '\[ValidateScript\([^\]]+\)\]', ''
                                    $desc.Trim()
                                } else { "" }
                                if ($paramDescription) {
                                    Add-Content -Path $runbookFilePath -Value $paramDescription
                                }
                                Add-Content -Path $runbookFilePath -Value ""
                                # Format type for display
                                $paramType = if ($parameter.type.name) {
                                    if ($parameter.type.name -eq 'String[]') {
                                        "String Array"
                                    } else {
                                        $parameter.type.name
                                    }
                                } else { "" }
                                Add-Content -Path $runbookFilePath -Value "| Property | Value |"
                                Add-Content -Path $runbookFilePath -Value "|----------|-------|"
                                Add-Content -Path $runbookFilePath -Value "| Default Value | $($parameter.DefaultValue) |"
                                Add-Content -Path $runbookFilePath -Value "| Required | $($parameter.Required) |"
                                Add-Content -Path $runbookFilePath -Value "| Type | $paramType |"
                                Add-Content -Path $runbookFilePath -Value ""
                            }
                        }
                    }
                }

                # Add link back to the primary folder TOC
                Add-Content -Path $runbookFilePath -Value ""
                Add-Content -Path $runbookFilePath -Value "[Back to Table of Content](../../../$($mainOutfile))"
                Add-Content -Path $runbookFilePath -Value ""
            }
        }
    }

    # Create TOC for each primary folder
    foreach ($primaryFolderOverviewFile in $primaryFolderOverviewFiles) {
        Add-Content -Path $primaryFolderOverviewFile -Value ""
        Add-Content -Path $primaryFolderOverviewFile -Value "[Back to Table of Content](../../$($mainOutfile))"
        Add-Content -Path $primaryFolderOverviewFile -Value ""
    }
    #endregion
}

#endregion

################################################################################################
# region Output missing runbook help
################################################################################################
if ($global:MissingRunbookHelp -notlike "") {
    Write-Output "The following runbooks are missing comment-based help:"
    Write-Output $global:MissingRunbookHelp
    Write-Output ""
}
# endregion