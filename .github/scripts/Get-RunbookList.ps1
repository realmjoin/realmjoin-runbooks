<#
    .SYNOPSIS
    This script collects information from all RealmJoin runbooks in a specified folder and generates based on parameters several markdown kind of lists documents with the runbook details.

    .DESCRIPTION
    This script collects information from all RealmJoin runbooks in a specified folder and generates based on parameters several markdown kind of lists documents with the runbook details. The script can create the following documents:
    - A list of all runbooks with a short description. The created document also contains a table of contents and backlinks to the table of contents. In this document, the information regarding the following parameters are included: Category, Subcategory, Runbook Name, Synopsis, Description
    - A compact list of all runbooks with a short description. The created document does not contain a table of contents or other links. In the list, the columns are Category, Subcategory, Runbook Name and Synopsis
    - A list of permissions and RBAC roles for each runbook. In the list, the columns are Category, Subcategory, Runbook Name, Synopsis, Permissions and RBAC Roles.

    .PARAMETER includedScope
    The scope of the runbooks to include, which represents the root folder of the runbooks. The default value is "device", "group", "org", "user".

    .PARAMETER createRunbookOverviewList
    Creates a list of all runbooks with a short description. The created document also contains a table of contents and backlinks to the table of contents.
    In this document, the information regarding the following parameters are included: Category, Subcategory, Runbook Name, Synopsis, Description
    The name of this list is "RealmJoinRunbook-RunbookList.md"

    .PARAMETER createCompactRunbookOverviewList
    Creates a compact list of all runbooks with a short description. The created document does not contain a table of contents or other links.
    In the list, the columns are Category, Subcategory, Runbook Name and Synopsis
    The name of this list is "RealmJoinRunbook-RunbookListCompact.md"

    .PARAMETER createPermissionList
    Creates a list of permissions and RBAC roles for each runbook.
    In the list, the columns are Category, Subcategory, Runbook Name, Synopsis, Permissions and RBAC Roles.
    The name of this list is "RealmJoinRunbook-PermissionOverview.md"

    .PARAMETER createParameterList
    Creates a list of all parameters for each runbook.
    In the list, the columns are Category, Subcategory, Runbook Name, Synopsis, Parameter, Required and Type.
    Each parameter is listed in a separate row. The runbook name and synopsis are only shown once per runbook.
    The name of this list is "RealmJoinRunbook-RunbookParameterList.md"

    .PARAMETER createCustomRunbookList
    Creates a custom list located in the sub folder "custom" which extends the compact runbook list with parameter information.
    The list preserves the compact tabular structure but adds the parameter columns (Parameter, Required, Type, Description).
    The name of this list is "custom/RealmJoinRunbook-RunbookListWithParameters.md"

    .PARAMETER outputFolder
    The output folder for the generated markdown files or depending on the output mode for the generated folder structure. The default value is the folder "docs" in the current location.

    .PARAMETER rootFolder
    The root folder where the script should start to search for runbooks. The default value is the current location.

    .NOTES
    The script needs read/write access to the root folder and the output folder. The script will create the output folder if it does not exist.

#>


param(
    [string[]]$includedScope = @("device", "group", "org", "user"),
    [switch]$createRunbookOverviewList,
    [switch]$createCompactRunbookOverviewList,
    [switch]$createPermissionList,
    [switch]$createParameterList,
    [switch]$createCustomRunbookList,
    [string]$outputFolder = $(Join-Path -Path (Get-Location).Path -ChildPath "docs"),
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

    # Fix common acronyms to be uppercase
    $runbookDisplayName = $runbookDisplayName -replace '\bMdm\b', 'MDM' -replace '\bAvd\b', 'AVD' -replace '\bAad\b', 'AAD' -replace '\bMfa\b', 'MFA' -replace '\bPim\b', 'PIM' -replace '\bCa\b', 'CA' -replace '\bPal\b', 'PAL' -replace '\bLaps\b', 'LAPS' -replace '\bOwa\b', 'OWA' -replace '\bTpm\b', 'TPM'
    $runbookDisplayPath = $runbookDisplayPath -replace '\bMdm\b', 'MDM' -replace '\bAvd\b', 'AVD' -replace '\bAad\b', 'AAD' -replace '\bMfa\b', 'MFA' -replace '\bPim\b', 'PIM' -replace '\bCa\b', 'CA' -replace '\bPal\b', 'PAL' -replace '\bLaps\b', 'LAPS' -replace '\bOwa\b', 'OWA' -replace '\bTpm\b', 'TPM'

    # Replace _Scheduled with (Scheduled)
    $runbookDisplayName = $runbookDisplayName -replace '_Scheduled$', ' (Scheduled)'
    $runbookDisplayPath = $runbookDisplayPath -replace '_Scheduled$', ' (Scheduled)'

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
        $permissionsMarkdown += "- **Type**: $($permission.Name)<br>"
        foreach ($assignment in $permission.AppRoleAssignments) {
            $permissionsMarkdown += "&emsp;- $assignment<br>"
        }
    }

    foreach ($role in $jsonObject.Roles) {
        $rbacRolesMarkdown += "- $role<br>"
    }

    foreach ($manualPermission in $jsonObject.ManualPermissions) {
        $manualPermissionsMarkdown += "$manualPermission<br>"
    }

    return @{
        Permissions = $permissionsMarkdown
        RBACRoles   = $rbacRolesMarkdown
        ManualPermissions = $manualPermissionsMarkdown
    }
}

function ConvertTo-MarkdownCellValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$InputText
    )

    if ($null -eq $InputText) {
        return ""
    }

    $text = if ($InputText -is [System.Array]) {
        ($InputText -join "`n")
    }
    else {
        [string]$InputText
    }

    $text = $text -replace "(\r\n|\n|\r)", "<br>"
    return $text.Trim()
}

function Get-ParameterDescriptionText {
    param(
        [Parameter(Mandatory = $false)]
        [object]$DescriptionObject
    )

    if ($null -eq $DescriptionObject) {
        return ""
    }

    $text = if ($DescriptionObject -is [System.Array]) {
        ($DescriptionObject -join "`n")
    }
    else {
        [string]$DescriptionObject
    }

    $text = $text -replace '\[ValidateScript\([^\]]+\)\]', ''
    return ConvertTo-MarkdownCellValue -InputText $text
}

function Get-RunbookSynopsisText {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Synopsis,
        [Parameter(Mandatory = $false)]
        [object]$Description
    )

    if ($Synopsis) {
        return ConvertTo-MarkdownCellValue -InputText $Synopsis
    }
    elseif ($Description) {
        return ConvertTo-MarkdownCellValue -InputText $Description
    }

    return ""
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

    # Replace "Org" with "Organization"
    if ($primaryFolder -eq "Org") {
        $primaryFolder = "Organization"
    }

    # Fix common acronyms to be uppercase in folder names
    $subFolder = $subFolder -replace '\bMdm\b', 'MDM' -replace '\bAvd\b', 'AVD' -replace '\bAad\b', 'AAD' -replace '\bMfa\b', 'MFA' -replace '\bPim\b', 'PIM' -replace '\bCa\b', 'CA' -replace '\bPal\b', 'PAL' -replace '\bLaps\b', 'LAPS' -replace '\bOwa\b', 'OWA' -replace '\bTpm\b', 'TPM'

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
    }
}

#endregion

######################################
#region Generate markdown files
######################################

# Check if the output folder exists, if not try create it.
Write-Output "Checking if the output folder $outputFolder exists..."
try {
    if (-not (Test-Path -Path $outputFolder)) {
        New-Item -Path $outputFolder -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Output "The output folder did not exist and has been successfully created now"
    }
}
catch {
    Write-Error "Error creating the output folder $outputFolder - Error: $_"
    exit 1
}


######################################
#region Generate Runbook overview list
######################################

if ($createRunbookOverviewList) {
    $ListFile_Overview = Join-Path -Path $outputFolder -ChildPath "RealmJoinRunbook-RunbookList.md"
    if (Test-Path -Path $ListFile_Overview) {
        Remove-Item -Path $ListFile_Overview -Force -ErrorAction SilentlyContinue
    }

    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder

    Add-Content -Path $ListFile_Overview -Value "<a name='runbook-overview'></a>"
    Add-Content -Path $ListFile_Overview -Value "# Overview"
    Add-Content -Path $ListFile_Overview -Value "This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality."
    Add-Content -Path $ListFile_Overview -Value ""
    Add-Content -Path $ListFile_Overview -Value "To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:"
    foreach ($scope in $includedScope) {
        Add-Content -Path $ListFile_Overview -Value "- $scope"
    }
    Add-Content -Path $ListFile_Overview -Value ""
    Add-Content -Path $ListFile_Overview -Value "Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory."
    Add-Content -Path $ListFile_Overview -Value ""

    # Create TOC
    Add-Content -Path $ListFile_Overview -Value "# Table of Contents"

    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$($primaryFolderAnchor)-$(($subFolder -replace ' ', '-').ToLower())"

        if ($lastPrimaryFolder -ne $primaryFolder) {
            Add-Content -Path $ListFile_Overview -Value "- [$primaryFolder](#$primaryFolderAnchor)"
            $lastPrimaryFolder = $primaryFolder
        }

        Add-Content -Path $ListFile_Overview -Value "  - [$subFolder](#$subFolderAnchor)"

        foreach ($runbook in $primaryGroup.Group) {
            Add-Content -Path $ListFile_Overview -Value "    - $($runbook.RunbookDisplayName)"
        }
    }

    Add-Content -Path $ListFile_Overview -Value ""

    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$($primaryFolderAnchor)-$(($subFolder -replace ' ', '-').ToLower())"

        if ($lastPrimaryFolder -ne $primaryFolder) {
            Add-Content -Path $ListFile_Overview -Value "<a name='$primaryFolderAnchor'></a>"
            Add-Content -Path $ListFile_Overview -Value "# $primaryFolder"
            $lastPrimaryFolder = $primaryFolder
        }

        Add-Content -Path $ListFile_Overview -Value "<a name='$subFolderAnchor'></a>"
        Add-Content -Path $ListFile_Overview -Value "## $subFolder"

        Add-Content -Path $ListFile_Overview -Value "| Runbook Name | Synopsis |"
        Add-Content -Path $ListFile_Overview -Value "|--------------|----------|"

        foreach ($runbook in $primaryGroup.Group) {
            $synopsis = Get-RunbookSynopsisText -Synopsis $runbook.Synopsis -Description $runbook.Description
            Add-Content -Path $ListFile_Overview -Value "| $($runbook.RunbookDisplayName) | $synopsis |"
        }
        Add-Content -Path $ListFile_Overview -Value ""
        Add-Content -Path $ListFile_Overview -Value "[Back to the RealmJoin runbook overview](#table-of-contents)"
        Add-Content -Path $ListFile_Overview -Value ""
    }
}
#endregion

######################################
#region Generate Compact Runbook overview list
######################################

if ($createCompactRunbookOverviewList) {
    $ListFile_Compact = Join-Path -Path $outputFolder -ChildPath "RealmJoinRunbook-RunbookListCompact.md"
    if (Test-Path -Path $ListFile_Compact) {
        Remove-Item -Path $ListFile_Compact -Force -ErrorAction SilentlyContinue
    }

    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder

    Add-Content -Path $ListFile_Compact -Value "# Overview"
    Add-Content -Path $ListFile_Compact -Value "This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality."
    Add-Content -Path $ListFile_Compact -Value ""

    # Create a table of all runbooks which includes the following columns: PrimaryFolder, SubFolder, RunbookDisplayName, Synopsis
    Add-Content -Path $ListFile_Compact -Value "| Category | Subcategory | Runbook Name | Synopsis |"
    Add-Content -Path $ListFile_Compact -Value "|----------|-------------|--------------|----------|"
    $lastPrimaryFolder = ""
    $lastSubFolder = ""
    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        foreach ($runbook in $primaryGroup.Group) {
            $synopsis = Get-RunbookSynopsisText -Synopsis $runbook.Synopsis -Description $runbook.Description
            $primaryFolderValue = if ($lastPrimaryFolder -ne $primaryFolder) { $primaryFolder } else { "" }
            $subFolderValue = if ($lastSubFolder -ne $subFolder) { $subFolder } else { "" }
            Add-Content -Path $ListFile_Compact -Value "| $primaryFolderValue | $subFolderValue | $($runbook.RunbookDisplayName) | $synopsis |"
            $lastPrimaryFolder = $primaryFolder
            $lastSubFolder = $subFolder
        }
    }
}

#endregion

######################################
#region Generate Permission overview list
######################################

if ($createPermissionList) {
    $PermissionFile = Join-Path -Path $outputFolder -ChildPath "RealmJoinRunbook-PermissionOverview.md"
    if (Test-Path -Path $PermissionFile) {
        Remove-Item -Path $PermissionFile -Force -ErrorAction SilentlyContinue
    }

    Add-Content -Path $PermissionFile -Value "# Overview"
    Add-Content -Path $PermissionFile -Value "This document provides an overview of the permissions and RBAC roles required for each runbook in the RealmJoin portal. The permissions and roles are listed to ensure that the necessary access rights are granted to the appropriate users and groups."
    Add-Content -Path $PermissionFile -Value ""

    # Create a table of all runbooks which includes the following columns: PrimaryFolder, SubFolder, RunbookDisplayName, Synopsis, Permissions, RBAC Roles
    # Keep Runbook Name, Permissions and RBAC Roles wider than the other columns (based on non-breaking spaces) - 20 spaces. Currently not in used cause GitHub View does not looks better with this...
    $WideColumn = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
    Add-Content -Path $PermissionFile -Value "| Category | Subcategory | Runbook Name | Synopsis | Permissions | RBAC Roles |"
    Add-Content -Path $PermissionFile -Value "|----------|-------------|--------------|----------|-------------|------------|"
    $lastPrimaryFolder = ""
    $lastSubFolder = ""
    foreach ($runbook in $runbookDescriptions) {
        $primaryFolderValue = if ($lastPrimaryFolder -ne $runbook.PrimaryFolder) { $runbook.PrimaryFolder } else { "" }
        $subFolderValue = if ($lastSubFolder -ne $runbook.SubFolder) { $runbook.SubFolder } else { "" }

        $permissionsMarkdown = ""
        $rbacRolesMarkdown = ""
        if ($runbook.PermissionsContent) {
            $permissionsAndRoles = Convert-PermissionJsonToMarkdown -JsonContent $runbook.PermissionsContent
            $permissionsMarkdown = $permissionsAndRoles.Permissions
            if ($permissionsAndRoles.ManualPermissions) {
                $permissionsMarkdown += $permissionsAndRoles.ManualPermissions
            }
            $rbacRolesMarkdown = $permissionsAndRoles.RBACRoles
        }

        $synopsis = Get-RunbookSynopsisText -Synopsis $runbook.Synopsis -Description $runbook.Description
        Add-Content -Path $PermissionFile -Value "| $primaryFolderValue | $subFolderValue | $($runbook.RunbookDisplayName) | $synopsis | $permissionsMarkdown | $rbacRolesMarkdown |"
        $lastPrimaryFolder = $runbook.PrimaryFolder
        $lastSubFolder = $runbook.SubFolder
    }
}

#endregion

######################################
#region Generate Custom runbook compact parameter list
######################################

if ($createCustomRunbookList) {
    $customFolder = Join-Path -Path $outputFolder -ChildPath "custom"
    if (-not (Test-Path -Path $customFolder)) {
        New-Item -Path $customFolder -ItemType Directory -Force | Out-Null
    }

    $CustomFile = Join-Path -Path $customFolder -ChildPath "RealmJoinRunbook-RunbookListWithParameters.md"
    if (Test-Path -Path $CustomFile) {
        Remove-Item -Path $CustomFile -Force -ErrorAction SilentlyContinue
    }

    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder

    Add-Content -Path $CustomFile -Value "# Overview"
    Add-Content -Path $CustomFile -Value "This document combines the compact RealmJoin runbook overview with detailed parameter information."
    Add-Content -Path $CustomFile -Value ""
    Add-Content -Path $CustomFile -Value "| Category | Subcategory | Runbook Name | Synopsis | Parameter | Required | Type | Parameter Description |"
    Add-Content -Path $CustomFile -Value "|----------|-------------|--------------|----------|-----------|----------|------|-----------------------|"

    $lastPrimaryFolder = ""
    $lastSubFolder = ""

    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()

        foreach ($runbook in $primaryGroup.Group) {
            $synopsis = Get-RunbookSynopsisText -Synopsis $runbook.Synopsis -Description $runbook.Description
            $primaryFolderValue = if ($lastPrimaryFolder -ne $primaryFolder) { $primaryFolder } else { "" }
            $subFolderValue = if (($lastPrimaryFolder -ne $primaryFolder) -or ($lastSubFolder -ne $subFolder)) { $subFolder } else { "" }

            if (-not $runbook.Parameters -or $runbook.Parameters.Count -eq 0) {
                Add-Content -Path $CustomFile -Value "| $primaryFolderValue | $subFolderValue | $($runbook.RunbookDisplayName) | $synopsis | - | - | - | - |"
            }
            else {
                $firstParam = $runbook.Parameters[0]
                $firstRequired = if ($firstParam.required -eq $true -or $firstParam.required -eq 'true') { "✓" } else { "" }
                $firstType = if ($firstParam.type.name) {
                    if ($firstParam.type.name -eq 'String[]') {
                        "String Array"
                    }
                    else {
                        $firstParam.type.name
                    }
                }
                else { "" }
                $firstDescription = if ($firstParam.description) {
                    Get-ParameterDescriptionText -DescriptionObject $firstParam.description.Text
                }
                else { "" }

                Add-Content -Path $CustomFile -Value "| $primaryFolderValue | $subFolderValue | $($runbook.RunbookDisplayName) | $synopsis | $($firstParam.name) | $firstRequired | $firstType | $firstDescription |"

                for ($i = 1; $i -lt $runbook.Parameters.Count; $i++) {
                    $param = $runbook.Parameters[$i]
                    $isRequired = if ($param.required -eq $true -or $param.required -eq 'true') { "✓" } else { "" }
                    $paramType = if ($param.type.name) {
                        if ($param.type.name -eq 'String[]') {
                            "String Array"
                        }
                        else {
                            $param.type.name
                        }
                    }
                    else { "" }
                    $paramDescription = if ($param.description) {
                        Get-ParameterDescriptionText -DescriptionObject $param.description.Text
                    }
                    else { "" }

                    Add-Content -Path $CustomFile -Value "|  |  |  |  | $($param.name) | $isRequired | $paramType | $paramDescription |"
                }
            }

            $lastPrimaryFolder = $primaryFolder
            $lastSubFolder = $subFolder
        }
    }
}

#endregion

######################################
#region Generate Parameter overview list
######################################

if ($createParameterList) {
    $ParameterFile = Join-Path -Path $outputFolder -ChildPath "RealmJoinRunbook-RunbookParameterList.md"
    if (Test-Path -Path $ParameterFile) {
        Remove-Item -Path $ParameterFile -Force -ErrorAction SilentlyContinue
    }

    $groupedRunbooks = $runbookDescriptions | Group-Object -Property PrimaryFolder, SubFolder

    Add-Content -Path $ParameterFile -Value "<a name='runbook-parameter-overview'></a>"
    Add-Content -Path $ParameterFile -Value "# Overview"
    Add-Content -Path $ParameterFile -Value "This document provides a comprehensive overview of all parameters used in the runbooks available in the RealmJoin portal. Each parameter is listed with its type and whether it is required or optional."
    Add-Content -Path $ParameterFile -Value ""
    Add-Content -Path $ParameterFile -Value "To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:"
    foreach ($scope in $includedScope) {
        Add-Content -Path $ParameterFile -Value "- $scope"
    }
    Add-Content -Path $ParameterFile -Value ""
    Add-Content -Path $ParameterFile -Value "Each category contains multiple runbooks that are further divided into subcategories based on their functionality. For runbooks with multiple parameters, each parameter is listed in a separate row."
    Add-Content -Path $ParameterFile -Value ""

    # Create TOC
    Add-Content -Path $ParameterFile -Value "# Table of Contents"

    $lastPrimaryFolder = ""
    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$($primaryFolderAnchor)-$(($subFolder -replace ' ', '-').ToLower())"

        if ($lastPrimaryFolder -ne $primaryFolder) {
            Add-Content -Path $ParameterFile -Value "- [$primaryFolder](#$primaryFolderAnchor)"
            $lastPrimaryFolder = $primaryFolder
        }

        Add-Content -Path $ParameterFile -Value "  - [$subFolder](#$subFolderAnchor)"

        foreach ($runbook in $primaryGroup.Group) {
            $runbookAnchor = "$($subFolderAnchor)-$(($runbook.RunbookDisplayName -replace ' ', '-' -replace '[()]', '').ToLower())"
            Add-Content -Path $ParameterFile -Value "    - [$($runbook.RunbookDisplayName)](#$runbookAnchor)"
        }
    }

    Add-Content -Path $ParameterFile -Value ""

    # Create content sections
    $lastPrimaryFolder = ""
    foreach ($primaryGroup in $groupedRunbooks) {
        $primaryFolder = $primaryGroup.Name.Split(',')[0].Trim()
        $subFolder = $primaryGroup.Name.Split(',')[1].Trim()
        $primaryFolderAnchor = ($primaryFolder -replace ' ', '-').ToLower()
        $subFolderAnchor = "$($primaryFolderAnchor)-$(($subFolder -replace ' ', '-').ToLower())"

        if ($lastPrimaryFolder -ne $primaryFolder) {
            Add-Content -Path $ParameterFile -Value "<a name='$primaryFolderAnchor'></a>"
            Add-Content -Path $ParameterFile -Value "# $primaryFolder"
            $lastPrimaryFolder = $primaryFolder
        }

        Add-Content -Path $ParameterFile -Value "<a name='$subFolderAnchor'></a>"
        Add-Content -Path $ParameterFile -Value "## $subFolder"
        Add-Content -Path $ParameterFile -Value ""

        foreach ($runbook in $primaryGroup.Group) {
            $synopsis = Get-RunbookSynopsisText -Synopsis $runbook.Synopsis -Description $runbook.Description
            $runbookAnchor = "$($subFolderAnchor)-$(($runbook.RunbookDisplayName -replace ' ', '-' -replace '[()]', '').ToLower())"

            # Add runbook name and synopsis as heading with anchor
            Add-Content -Path $ParameterFile -Value "<a name='$runbookAnchor'></a>"
            Add-Content -Path $ParameterFile -Value ""
            Add-Content -Path $ParameterFile -Value "### $($runbook.RunbookDisplayName)"
            if ($synopsis) {
                Add-Content -Path $ParameterFile -Value "$synopsis"
                Add-Content -Path $ParameterFile -Value ""
            }

            # Create table for this runbook's parameters
            Add-Content -Path $ParameterFile -Value "| Parameter | Required | Type | Description |"
            Add-Content -Path $ParameterFile -Value "|-----------|----------|------|-------------|"

            # Handle runbooks with no parameters
            if (-not $runbook.Parameters -or $runbook.Parameters.Count -eq 0) {
                Add-Content -Path $ParameterFile -Value "| - | - | - | No parameters |"
            }
            else {
                # Add all parameters to the table
                foreach ($param in $runbook.Parameters) {
                    $isRequired = if ($param.required -eq $true -or $param.required -eq 'true') { "✓" } else { "" }
                    $paramType = if ($param.type.name) {
                        if ($param.type.name -eq 'String[]') {
                            "String Array"
                        } else {
                            $param.type.name
                        }
                    } else { "" }
                    # Format description for markdown tables
                    $paramDescription = if ($param.description) {
                        Get-ParameterDescriptionText -DescriptionObject $param.description.Text
                    } else { "" }

                    Add-Content -Path $ParameterFile -Value "| $($param.name) | $isRequired | $paramType | $paramDescription |"
                }
            }
            Add-Content -Path $ParameterFile -Value ""
        }
        Add-Content -Path $ParameterFile -Value "[Back to the RealmJoin runbook parameter overview](#table-of-contents)"
        Add-Content -Path $ParameterFile -Value ""
    }
}

#endregion
