<#

.SYNOPSIS
    Add a GSA application registration to Azure AD

.DESCRIPTION
    This script creates a new Global Secure Access Application registration in Azure Active Directory (Entra ID) with comprehensive configuration options.

    In addition to the application, a security group for managing access to the application is created (naming scheme configurable
    via Runbook Customization) and assigned to the application's service principal.

    If the application already exists, the runbook runs in update mode: app creation is skipped and only the segment /
    group / assignment steps are performed. All lookups (e.g. connector group) are validated BEFORE anything is created.
    If a later step fails anyway, objects created in this run (application, group) are rolled back and removed.
    Pre-existing objects (update mode) are never removed.

.PARAMETER name
    The base name of the Global Secure Access application to create. The final application name is built as "<prefix> <name>".

.PARAMETER prefix
    Prefix added to the application name. A space is inserted between prefix and name unless the prefix ends
    with "-", "_" or a space. Example: prefix "GSA-" + name "MyApp" results in application "GSA-MyApp".

.PARAMETER groupPrefix
    Prefix for the security group name. The group name is built as "<groupPrefix><name><groupSuffix>" -
    independent of the application prefix. Example: groupPrefix "App - Entra - GSA - " + name "MyApp"
    results in group "App - Entra - GSA - MyApp". Default: "App - Entra - GSA - ".

.PARAMETER groupSuffix
    Optional suffix for the security group name, e.g. " (users)". Default: empty.

.PARAMETER applicationType
    The type of GSA application to create. Options: "nonwebapp" (Enterprise App) or "quickaccessapp" (Quick Access App).

.PARAMETER connectorGroup
    The connectorGroup to be used for the application. Must be defined in the Runbook Customization.

.PARAMETER destinationHost
    The destination host or IP range for the application. Supports formats: FQDN (example.com), single IP (192.168.0.1), CIDR notation (192.168.0.1/24), or IP range (192.168.0.1..192.168.0.20).

.PARAMETER destinationType
    The type of destination specified. Options: "fqdn", "ip", "ipRangeCidr", or "ipRange". Hidden in UI as it's automatically determined from destinationHost format.

.PARAMETER ports
    The port(s) to configure for the application. Supports single port (443), multiple ports (80,443), or port range (8000-8080).

.PARAMETER protocol
    The network protocol to use. Options: "tcp", "udp", or "tcp,udp". Default is "tcp".

.PARAMETER CallerName
    The name of the user executing the runbook. Used for auditing purposes. Hidden in UI.

.INPUTS
    RunbookCustomization: {
    "Parameters": {
        "name": {
            "DisplayName": "Application Name (Must be unique)",
            "Hide": false
        },
        "prefix": {
            "DisplayName": "Application Name Prefix",
            "Default": "GSA-",
            "Hide": false
        },
        "groupPrefix": {
            "DisplayName": "Group name prefix (admin-defined, change via Runbook Customization)",
            "Default": "App - Entra - GSA - ",
            "ReadOnly": true,
            "Hide": false
        },
        "groupSuffix": {
            "Default": "",
            "Hide": true
        },
        "applicationType": {
            "DisplayName": "Application Type (Unique)",
            "Default": "nonwebapp",
            "Select": {
                "Options": [
                    {
                        "Display": "Enterprise App",
                        "ParameterValue": "nonwebapp"
                    },
                    {
                        "Display": "Quick Access App",
                        "ParameterValue": "quickaccessapp"
                    }
                ],
                "ShowValue": false
            }
        },
        "CallerName": {
            "Hide": true
        },
        "connectorGroup": {
            "DisplayName": "Connector Group (Please define your connector groups in the Runbook Customization)",
            "Hide": false
        },
        "destinationHost": {
            "DisplayName": "Destination Host or Range: example.com / 192.168.0.1 / 192.168.0.1/24 / 192.168.0.1..192.168.0.20",
            "Hide": false
        },
        "destinationType": {
            "Hide": true
        },
        "ports": {
            "DisplayName": "Ports (e.g., 443 or 80,443 or 8000-8080)",
            "Hide": false
        },
        "protocol": {
            "DisplayName": "Protocol",
            "Default": "tcp",
            "Select": {
                "Options": [
                    {
                        "Display": "TCP",
                        "ParameterValue": "tcp"
                    },
                    {
                        "Display": "UDP",
                        "ParameterValue": "udp"
                    },
                    {
                        "Display": "TCP,UDP",
                        "ParameterValue": "tcp,udp"
                    }
                ],
                "ShowValue": false
            }
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $name,
    [Parameter(Mandatory = $true)]
    [string] $prefix,
    [string] $groupPrefix = "App - Entra - GSA - ",
    [string] $groupSuffix = "",
    [Parameter(Mandatory = $true)]
    [string] $applicationType, # nonwebapp | quickaccessapp
    [string] $connectorGroup,
    [string] $destinationHost,
    [string] $destinationType, # fqdn | ip | ipRangeCidr | ipRange
    [string] $ports,
    [string] $protocol, # tcp | udp | tcp,udp
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.3.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

########################################################
#region     Function Declaration Part
##
########################################################

# Set the destinationType based on the destinationHost Input
function Get-DestinationType {
    param(
        [string]$destination
    )

    $destination = $destination.Trim()

    # Check for ipRange (contains ..)
    if ($destination -match '\.\.') {
        return "ipRange"
    }

    # Check for ipRangeCidr (contains /)
    if ($destination -match '/') {
        return "ipRangeCidr"
    }

    # Check for IP address (four octets separated by dots, all numeric)
    if ($destination -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
        return "ip"
    }

    # Default to fqdn (domain name)
    return "fqdn"
}

# Function to check if the Name is valid
function Test-Name {
    param (
        [string]$name
    )

    # Check if the name is empty or null
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Warning "Name cannot be empty or null."
        return $false
    }

    # Check if the name contains any reserved words
    foreach ($word in $reservedWords) {
        if ($name -match $word) {
            Write-Warning "Name contains a reserved word: $word."
            return $false
        }
    }

    # Check if the name meets length requirements (example: 1-256 characters)
    if ($name.Length -lt 1 -or $name.Length -gt 256) {
        Write-Warning "Name must be between 1 and 256 characters."
        return $false
    }

    # Check for invalid characters (example: only letters, numbers, hyphens, and underscores)
    if ($name -notmatch '^[a-zA-Z0-9-_ ]+$') {
        Write-Warning "Name contains invalid characters. Only letters, numbers, blanks, hyphens, and underscores are allowed."
        return $false
    }

    return $true
}

# Function to create the group
function New-Group {
    param (
        [string]$groupName,
        [Parameter(Mandatory = $false)]
        [string]$groupDescription
    )
    $uri = "https://graph.microsoft.com/v1.0/groups"

    # mailNickname must not contain spaces or special characters
    $mailNickname = ($groupName -replace '[^a-zA-Z0-9\-_.]', '')
    if ([string]::IsNullOrWhiteSpace($mailNickname)) {
        $mailNickname = "group" + (Get-Random -Maximum 99999)
    }

    $body = @{
        displayName     = $groupName
        mailEnabled     = $false
        mailNickname    = $mailNickname
        securityEnabled = $true
        groupTypes      = @()
        visibility      = "Private"
    }

    if (![string]::IsNullOrWhiteSpace($groupDescription)) {
        $body.description = $groupDescription
    }

    $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
    return $response
}

#endregion

########################################################
#region     Connect Part
##
########################################################

Connect-MgGraph -Identity -NoWelcome

#endregion

########################################################
#region     Pre-Flight Validation Part
##
## All checks and lookups that can fail are done here,
## BEFORE any object is created.
########################################################

# List of reserved words disallowed in application / group names
$reservedWords = @("admin", "administrator", "system", "guest")

# Validate the base name
if (-not (Test-Name -name $name)) {
    Write-Error "The Name '$name' is not suitable for an application / Entra ID Security Group." -ErrorAction Stop
}

# Validate the prefix as well - it may be operator-provided free text depending on the
# Runbook Customization, and invalid characters (e.g. quotes) would break the Graph queries
if (-not (Test-Name -name $prefix)) {
    Write-Error "The Prefix '$prefix' is not suitable for an application / Entra ID Security Group name." -ErrorAction Stop
}

# Build final names from naming scheme.
# App: a space is inserted between prefix and name unless the prefix already ends with a separator ("-", "_" or " ").
# Group: built independently of the app prefix as "<groupPrefix><name><groupSuffix>".
if ($prefix -match '[-_ ]$') {
    $applicationName = "$prefix$name"
}
else {
    $applicationName = "$prefix $name"
}
$groupName = "$groupPrefix$name$groupSuffix"

"## Application name: '$applicationName'"
"## Group name: '$groupName'"

# Determine the destinationType from the destinationHost format
$destinationType = Get-DestinationType -destination $destinationHost

# Check whether all inputs for a segment are provided
$segmentVariables = @{
    connectorGroup  = $connectorGroup
    destinationHost = $destinationHost
    ports           = $ports
}
$emptyVars = $segmentVariables.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace($_.Value) } | ForEach-Object { $_.Key }
$addSegment = ($emptyVars.Count -eq 0)
if (-not $addSegment) {
    "## The following variables are empty: $($emptyVars -join ', '). Segment addition will be skipped."
}

# Resolve the connector group BEFORE creating anything - this was the most common
# failure that previously left a half-configured application behind.
$connectorGroupId = $null
if ($addSegment) {
    # Note: $filter on this beta endpoint is unreliable (may be silently ignored),
    # so all connector groups are retrieved and matched by name client-side.
    $connectorGroupResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationProxy/connectorGroups" -ContentType "application/json" -ErrorAction Stop
    $matchedConnectorGroup = @($connectorGroupResponse.value | Where-Object { $_.name -eq $connectorGroup })
    if ($matchedConnectorGroup.Count -eq 0) {
        $availableGroups = ($connectorGroupResponse.value | ForEach-Object { $_.name }) -join "', '"
        throw "Connector Group '$connectorGroup' not found. Available connector groups: '$availableGroups'. Please check the Runbook Customization. Nothing has been created."
    }
    $connectorGroupId = $matchedConnectorGroup[0].id
    "## Using Connector Group Id: $connectorGroupId"
}

# Check if an application with the same name already exists
$existingApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$applicationName'" -ContentType "application/json" -ErrorAction Stop

$continue = $true
if ($applicationType -eq "quickaccessapp") {
    $existingQuickAccessApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=tags/any(t:t eq 'NetworkAccessQuickAccessApplication')" -ContentType "application/json" -ErrorAction Stop
    if ($existingQuickAccessApp.value -and $existingQuickAccessApp.value.Count -gt 0) {
        $continue = $false # Flag to track existence of quickaccessapp
    }
}

# Check if the group already exists (update mode reuses it)
# groupPrefix/groupSuffix come from Runbook Customization - escape single quotes for the OData filter
$groupNameEscaped = $groupName -replace "'", "''"
$uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupNameEscaped'&`$select=id"
$existingGroup = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop).value

#endregion

########################################################
#region     Application Creation Part
##
########################################################

$applicationId = $null
$servicePrincipalId = $null
$appId = $null
$appCreatedInThisRun = $false

if ($continue) {
    if (-not $existingApp.value -or $existingApp.value.Count -eq 0) {
        "## Creating application '$applicationName'"

        # Create App with Template
        $response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/applicationTemplates/8adf8e6e-67b2-4cf2-a259-e3dc5476c621/instantiate" -Body @"
{
  "displayName": "$applicationName"
}
"@ -ContentType "application/json" -ErrorAction Stop

        # Specify application Type
        $applicationId = $response.application.id
        $appId = $response.application.appId
        $servicePrincipalId = $response.servicePrincipal.id
        $appCreatedInThisRun = $true

        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/applications/$applicationId" -Body @"
{
  "onPremisesPublishing":{
    "applicationType":"$applicationType",
    "isAccessibleViaZTNAClient": true
  }
}
"@ -ErrorAction Stop
        "## Application '$applicationName' created as: $applicationType"
    }
    else {
        $applicationId = $existingApp.value[0].id
        $appId = $existingApp.value[0].appId

        # Safety check: verify the existing application is actually a GSA / App Proxy application
        # before modifying it - a name collision with an unrelated app must not be touched.
        $isGsaApp = $false
        try {
            $betaApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/applications/$applicationId`?`$select=onPremisesPublishing" -ErrorAction Stop
            if ($betaApp.onPremisesPublishing -and $betaApp.onPremisesPublishing.applicationType) {
                $isGsaApp = $true
            }
        }
        catch {
            Write-RjRbLog -Message "Could not read onPremisesPublishing: $_" -Verbose
        }
        if (-not $isGsaApp) {
            throw "Application '$applicationName' already exists (id: $applicationId) but does not appear to be a GSA / App Proxy application (no onPremisesPublishing configuration). Aborting to avoid modifying an unrelated application. Nothing has been created."
        }

        "## Application '$applicationName' already exists, id: $($applicationId). Running in update mode - the application will not be removed on failure."
    }
}
# A Quick Access App already exists - reuse it for segment addition
$applicationId = $existingQuickAccessApp.value[0].id
$appId = $existingQuickAccessApp.value[0].appId
$applicationName = $existingQuickAccessApp.value[0].displayName
"## Using existing Quick Access App '$applicationName'. Running in update mode - the application will not be removed on failure."

#endregion

########################################################
#region     Configuration Part (with rollback)
##
## Everything from here on is wrapped in try/catch.
## On failure, objects created in THIS run are removed.
## Pre-existing objects (update mode) are never removed.
########################################################

$groupCreatedInThisRun = $false
$groupId = $null

try {
    ##########################
    ## Segment / Connector Group
    ##########################
    if ($addSegment) {
        # Wait for application to be fully provisioned
        $maxRetries = 10
        $retryCount = 0
        $appReady = $false
        while (-not $appReady -and $retryCount -lt $maxRetries) {
            try {
                $app = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/applications/$applicationId" -ErrorAction Stop
                if ($app.id) {
                    $appReady = $true
                    "## Application is ready for connector group assignment"
                }
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Seconds 2
                }
            }
        }

        if (-not $appReady) {
            throw "Application provisioning timeout - unable to verify application readiness"
        }

        # Assign App to Connector Group
        Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/applications/$applicationId/connectorGroup/`$ref" -Body @"
{
  "@odata.id":"https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationProxy/connectorGroups/$connectorGroupId"
}
"@ -ContentType "application/json" -ErrorAction Stop
        "## Assigned Application '$applicationName' to Connector Group Id: $connectorGroupId"

        # Add Application Segment
        # Split the ports string and normalize to range format
        $portsArray = @($ports -split ',' | ForEach-Object {
                $port = $_.Trim()
                if ($port -notmatch '-') {
                    # Single port - convert to range format
                    "$port-$port"
                }
                else {
                    # Already a range
                    $port
                }
            })

        $bodyObject = @{
            destinationHost = $destinationHost
            destinationType = $destinationType
            port            = 0
            ports           = $portsArray
            protocol        = $protocol
        }

        $Body = $bodyObject | ConvertTo-Json -Compress

        try {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/applications/$applicationId/onPremisesPublishing/segmentsConfiguration/microsoft.graph.ipSegmentConfiguration/applicationSegments" -Body $Body -ErrorAction Stop | Out-Null
        }
        catch {
            # On a segment overlap, Graph only reports the conflicting app's IDs - resolve the display name for a readable error
            if ($_ -match 'conflictingApplication=\{[^}]*"objectId":\s*"([0-9a-fA-F-]{36})"') {
                $conflictingAppId = $Matches[1]
                $conflictingAppName = $conflictingAppId
                try {
                    $conflictingApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$conflictingAppId`?`$select=displayName" -ErrorAction Stop
                    $conflictingAppName = $conflictingApp.displayName
                }
                catch {
                    Write-RjRbLog -Message "Could not resolve display name of conflicting application $conflictingAppId" -Verbose
                }
                throw "Segment '$destinationHost' (Ports: $ports, Protocol: $protocol) overlaps with an existing segment on application '$conflictingAppName' (objectId: $conflictingAppId). Remove/adjust the segment there or choose a different range."
            }
            throw
        }
        "## Added Application Segment to '$applicationName': Host='$destinationHost', Type='$destinationType', Ports='$ports', Protocol='$protocol'"
    }

    ##########################
    ## Group Creation
    ##########################
    # Set group description based on application type
if ($applicationType -eq "nonwebapp") {
    $groupDescription = "Security Group for the Enterprise Application '$applicationName'. This group is used for managing access to the application and can be removed when the application is deleted."
}
else {
    $groupDescription = "Security Group for the Quick Access Application '$applicationName'. This group is used for managing access to the application and can be removed when the application is deleted."
}

    if ($existingGroup -and $existingGroup.Count -gt 0) {
        $groupId = $existingGroup[0].id
        "## Group '$groupName' already exists, id: $groupId. Group creation will be skipped."
    }
    else {
        $newGroup = New-Group -groupName $groupName -groupDescription $groupDescription
        $groupId = $newGroup.id
        $groupCreatedInThisRun = $true
        "## Group '$groupName' created successfully, id: $groupId"
    }

    ##########################
    ## Group Assignment
    ##########################
    # Resolve the service principal of the application (if not already known from creation)
    if (-not $servicePrincipalId) {
        $spResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$appId'" -ContentType "application/json" -ErrorAction Stop
        if (-not $spResponse.value -or $spResponse.value.Count -eq 0) {
            throw "Service Principal for application '$applicationName' (appId: $appId) not found."
        }
        $servicePrincipalId = $spResponse.value[0].id
    }

    # Determine the appRole to assign: use the first enabled appRole allowing 'User' members,
    # fall back to the default access role (zero GUID) if none is defined
    $sp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId" -ErrorAction Stop
    $appRole = @($sp.appRoles | Where-Object { $_.isEnabled -and ($_.allowedMemberTypes -contains "User") })
    if ($appRole.Count -gt 0) {
        $appRoleId = $appRole[0].id
    }
    else {
        $appRoleId = "00000000-0000-0000-0000-000000000000"
    }

    # Check if the group is already assigned to the application
    $existingAssignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignedTo" -ErrorAction Stop
    $alreadyAssigned = @($existingAssignments.value | Where-Object { $_.principalId -eq $groupId })

    if ($alreadyAssigned.Count -gt 0) {
        "## Group '$groupName' is already assigned to application '$applicationName'. Skipping assignment."
    }
    else {
        Write-RjRbLog -Message "Assigning group '$groupId' to service principal '$servicePrincipalId' with appRoleId '$appRoleId'" -Verbose

        # A freshly created group/service principal may not be replicated yet, which surfaces as
        # 400 "Not a valid reference update" - retry with backoff until replication catches up.
        $maxRetries = 10
        $retryCount = 0
        $assigned = $false
        while (-not $assigned -and $retryCount -lt $maxRetries) {
            try {
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignedTo" -Body @"
{
  "appRoleId": "$appRoleId",
  "resourceId": "$servicePrincipalId",
  "principalId": "$groupId"
}
"@ -ContentType "application/json" -ErrorAction Stop | Out-Null
                $assigned = $true
                "## Assigned Group '$groupName' to Application '$applicationName'"
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-RjRbLog -Message "Group assignment attempt $retryCount failed (likely replication delay), retrying in 15 seconds... ($_)" -Verbose
                    Start-Sleep -Seconds 15
                }
                else {
                    throw "Failed to assign group '$groupName' (id: $groupId) to application '$applicationName' (SP: $servicePrincipalId, appRoleId: $appRoleId) after $maxRetries attempts: $_"
                }
            }
        }
    }
}
catch {
    $originalError = $_
    "## ERROR: $originalError"
    "## Rolling back objects created in this run..."

    if ($groupCreatedInThisRun -and $groupId) {
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$groupId" -ErrorAction Stop
            "## Rollback: removed group '$groupName' (id: $groupId)"
        }
        catch {
            Write-Warning "Rollback of group '$groupName' (id: $groupId) failed: $_ - please remove it manually."
        }
    }

    if ($appCreatedInThisRun -and $applicationId) {
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/applications/$applicationId" -ErrorAction Stop
            "## Rollback: removed application '$applicationName' (id: $applicationId)"
        }
        catch {
            Write-Warning "Rollback of application '$applicationName' (id: $applicationId) failed: $_ - please remove it manually."
        }
    }

    if (-not $appCreatedInThisRun) {
        "## Update mode: pre-existing application '$applicationName' was NOT removed."
    }

    throw $originalError
}

#endregion
