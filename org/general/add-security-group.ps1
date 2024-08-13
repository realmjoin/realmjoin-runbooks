<#
    .SYNOPSIS
    This runbook creates a Microsoft Entra ID security group with membership type "Assigned".
    .DESCRIPTION
    This runbook creates a Microsoft Entra ID security group with membership type "Assigned".
    .NOTES
    Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
    GraphAPI: 
    - Group.Create 
    .PARAMETER GroupName
    The name of the security group.
    .PARAMETER GroupDescription
    The description of the security group.
    .PARAMETER AssignableToRoles
    Indicates whether Microsoft Entra roles can be assigned to the group.
    .PARAMETER Owner
    The owner of the security group.
    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "GroupName": {
                "DisplayName":  "Name of the security group",
            },
            "GroupDescription": {
                "DisplayName":  "Description of this security group",
            },
            "AssignableToRoles": {
                "DisplayName":  "Microsoft Entra roles can be assigned to the group"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param (
    [Parameter(Mandatory=$true)]
    [string]$GroupName,

    [Parameter(Mandatory=$true)]
    [string]$GroupDescription,

    [Parameter(Mandatory=$false)]
    [bool]$AssignableToRoles = $false,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Owner" -Filter "userType eq 'Member'"} )]
    [Parameter(Mandatory=$true)]
    [string]$Owner,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
#region fuction declaration
# Function to check if the group name is valid
function Validate-GroupName {
    param (
        [string]$name
    )

    # Check if the name is empty or null
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Warning "Group name cannot be empty or null."
        return $false
    }

    # Check if the name contains any reserved words
    foreach ($word in $reservedWords) {
        if ($name -match $word) {
            Write-Warning "Group name contains a reserved word: $word."
            return $false
        }
    }

    # Check if the name meets length requirements (example: 1-256 characters)
    if ($name.Length -lt 1 -or $name.Length -gt 256) {
        Write-Warning "Group name must be between 1 and 256 characters."
        return $false
    }

    # Check for invalid characters (example: only letters, numbers, hyphens, and underscores)
    if ($name -notmatch '^[a-zA-Z0-9-_]+$') {
        Write-Warning "Group name contains invalid characters. Only letters, numbers, hyphens, and underscores are allowed."
        return $false
    }

    Write-Output "Group name is valid."
    return $true
}

# Function to create the group
function Create-Group {
    param (
        [string]$GroupName,
        [string]$GroupDescription,
        [bool]$AssignableToRoles,
        [string]$MembershipType,
        [string]$Owner
    )
    $OwnerString = "https://graph.microsoft.com/v1.0/users/$Owner"
    $uri = "https://graph.microsoft.com/v1.0/groups"
    $body = @{
        displayName = $GroupName
        description = $GroupDescription
        mailEnabled = $false
        mailNickname = $GroupName.Replace(" ", "")
        securityEnabled = $true
        groupTypes = @()
        visibility = "Private"
        'owners@odata.bind' = @($OwnerString)
    }
    $response = Invoke-MGGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json)
    return $response
}

#endregion

# Initiate Graph Session
Write-Output "Initiate Graph Session"
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit 
}


#region GroupName Validation
# List of reserved words (example list, you may need to expand this based on actual reserved words)
$reservedWords = @("admin", "administrator", "system", "guest")


# Validate the group name
$isValid = Validate-GroupName -name $GroupName

# Output the result
if ($isValid) {
    Write-Output "The group name '$GroupName' is suitable for an Entra ID Security Group."
} else {
    Write-Error "The group name '$GroupName' is not suitable for an Entra ID Security Group." -ErrorAction Stop
}
#endregion

#region Main script logic
try {
    $uri = 'https://graph.microsoft.com/v1.0/groups?$filter=displayName eq ' + "'" + $($GroupName)+ "'" + '&?$select=id'
    $existingGroup = (Invoke-MGGraphRequest -Method GET -Uri $uri).value
    if ($existingGroup.Count -gt 0) {
        Write-Error "Group '$GroupName' already exists."
    } else {
        $newGroup = Create-Group -GroupName $GroupName -GroupDescription $GroupDescription -AssignableToRoles $AssignableToRoles -MembershipType $MembershipType -Owner $Owner
        Write-Output "Group '$GroupName' created successfully."
    }
} catch {
    Write-Error "An error occurred: $_"
}
#endregion
