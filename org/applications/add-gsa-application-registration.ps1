<#

.SYNOPSIS
    Add an GSA application registration to Azure AD

.DESCRIPTION
    This script creates a new Global Secure Access Application registration in Azure Active Directory (Entra ID) with comprehensive configuration options.
    
    The script validates input parameters, prevents duplicate application creation, and provides comprehensive logging
    throughout the process.

.INPUTS
    RunbookCustomization: {
    "Parameters": {
        "applicationName": {
            "DisplayName": "Application Name (Must be unique)",
            "Hide": false
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
        "connector": {
            "DisplayName": "Connector (Please define your connectors in the Runbook Customization)",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $applicationName,
    [Parameter(Mandatory = $true)]
    [string] $applicationType, # nonwebapp | quickaccessapp
    [string] $connector,
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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################
Connect-MgGraph -Identity -NoWelcome

#endregion

########################################################
#region     Execution Part
##
########################################################
# Set the destinationType based on the destinationHost Input
function Get-DestinationType {
    param([string]$destination)
    
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

# Usage
$destinationType = Get-DestinationType -destination $destinationHost

# Check if an application with the same name already exists
$existingApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$applicationName'" -ContentType "application/json" -ErrorAction Stop

$continue = $true
if ($applicationType -eq "quickaccessapp") {
    $existingQuickAccessApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=tags/any(t:t eq 'NetworkAccessQuickAccessApplication')" -ContentType "application/json" -ErrorAction Stop
    if ($existingQuickAccessApp.value -and $existingQuickAccessApp.value.Count -gt 0) {
        $continue = $false # Flag to track existence of quickaccessapp
    }
}

$applicationId = $existingApp.Value.id
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
        "## Application '$applicationName' already exists, id: $($applicationId). App creation will be skipped and only a new segment will be added"
    } 
} else {
    "## Application of type 'quickaccessapp' already exists. App creation will be skipped and only a new segment will be added"
}

$segmentVariables = @{
    connector       = $connector
    destinationHost = $destinationHost
    ports           = $ports
}
# Find variables that are null, empty, or whitespace
$emptyVars = $segmentVariables.GetEnumerator() | Where-Object { [string]::IsNullOrWhiteSpace($_.Value) } | ForEach-Object { $_.Key }

if ($emptyVars.Count -gt 0) {
    "## The following variables are empty: $($emptyVars -join ', '). Skipping segment addition."
} else {
    # Get Connector Group Id
    $connectorGroupResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationProxy/connectorGroups?`$filter=name eq 'Default'" -ContentType "application/json" -ErrorAction Stop
    $connectorGroupId = $connectorGroupResponse.value[0].id
    "## Using Connector Group Id: $connectorGroupId"


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
  "@odata.id":"https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationproxy/connectorGroups/$connectorGroupId"
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
    } else {
        # Already a range
        $port
    }
})

    $bodyObject = @{
        destinationHost = $destinationHost
        destinationType = $destinationType
        port = 0
        ports = $portsArray
        protocol = $protocol
    }

    $Body = $bodyObject | ConvertTo-Json -Compress

    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/applications/$applicationId/onPremisesPublishing/segmentsConfiguration/microsoft.graph.ipSegmentConfiguration/applicationSegments" -Body $Body -ErrorAction Stop
    "## Added Application Segment to '$applicationName': Host='$destinationHost', Type='$destinationType', Ports='$ports', Protocol='$protocol'"
    #endregion
}