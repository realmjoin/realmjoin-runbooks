<#
	.SYNOPSIS
	Create a Microsoft Entra ID security group

	.DESCRIPTION
	This runbook creates a Microsoft Entra ID security group with membership type Assigned.
	It validates the group name and optionally sets an owner during creation.

	.PARAMETER GroupName
	Display name of the security group to create.

	.PARAMETER GroupDescription
	Optional description for the security group.

	.PARAMETER Owner
	Optional owner to assign to the group.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"GroupName": {
				"DisplayName": "Name of the security group"
			},
			"GroupDescription": {
				"DisplayName": "Description of this security group"
			},
			"Owner": {
				"DisplayName": "Owner (optional)"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param (
    [Parameter(Mandatory = $true)]
    [string]$GroupName,

    [Parameter(Mandatory = $false)]
    [string]$GroupDescription,

    # Currently deactivated, as extended rights are required. See info in “.Notes”
    # [Parameter(Mandatory=$false)]
    # [bool]$AssignableToRoles = $false,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Owner" -Filter "userType eq 'Member'" } )]
    [Parameter(Mandatory = $false)]
    [string]$Owner,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

#region fuction declaration
# Function to check if the group name is valid
function Test-GroupName {
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
    if ($name -notmatch '^[a-zA-Z0-9-_ ]+$') {
        Write-Warning "Group name contains invalid characters. Only letters, numbers, blanks, hyphens, and underscores are allowed."
        return $false
    }

    Write-Output "Group name is valid."
    return $true
}

# Function to create the group
function New-Group {
    param (
        [string]$GroupName,
        [Parameter(Mandatory = $false)]
        [string]$GroupDescription,
        #[bool]$AssignableToRoles, # Currently deactivated, as extended rights are required. See info in “.Notes”
        [string]$MembershipType,
        [Parameter(Mandatory = $false)]
        [string]$Owner
    )
    $OwnerString = "https://graph.microsoft.com/v1.0/users/$Owner"
    $uri = "https://graph.microsoft.com/v1.0/groups"
    $body = @{
        displayName     = $GroupName
        mailEnabled     = $false
        mailNickname    = $GroupName.Replace(" ", "")
        securityEnabled = $true
        groupTypes      = @()
        visibility      = "Private"
    }

    if (![string]::IsNullOrWhiteSpace($GroupDescription)) {
        $body.description = $GroupDescription
    }

    if (![string]::IsNullOrWhiteSpace($Owner)) {
        $body.'owners@odata.bind' = @($OwnerString)
    }

    # Currently deactivated, as extended rights are required. See info in “.Notes”
    # if($AssignableToRoles) {
    #     $body.isAssignableToRole = $true
    # }else {
    #     $body.isAssignableToRole = $false
    # }


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
$isValid = Test-GroupName -name $GroupName

# Output the result
if ($isValid) {
    Write-Output "The group name '$GroupName' is suitable for an Entra ID Security Group."
}
else {
    Write-Error "The group name '$GroupName' is not suitable for an Entra ID Security Group." -ErrorAction Stop
}
#endregion

#region Main script logic
try {
    $uri = 'https://graph.microsoft.com/v1.0/groups?$filter=displayName eq ' + "'" + $($GroupName) + "'" + '&?$select=id'
    $existingGroup = (Invoke-MGGraphRequest -Method GET -Uri $uri).value
    if ($existingGroup.Count -gt 0) {
        Write-Error "Group '$GroupName' already exists."
    }
    else {
        $newGroup = New-Group -GroupName $GroupName -GroupDescription $GroupDescription -MembershipType $MembershipType -Owner $Owner # -AssignableToRoles $AssignableToRoles # Currently deactivated, as extended rights are required. See info in “.Notes”
        Write-Output "Group '$GroupName' created successfully."
    }
}
catch {
    Write-Error "An error occurred: $_"
}
#endregion
