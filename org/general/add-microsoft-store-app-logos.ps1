<#
  .SYNOPSIS
  Update logos of Microsoft Store Apps (new) in Intune.

  .DESCRIPTION
  This script updates the logos for Microsoft Store Apps (new) in Intune by fetching them from the Microsoft Store.

  .NOTES
  Permissions:
  MS Graph (API):
  - DeviceManagementApps.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

function Get-Base64EncodedImage {
    param (
        [string]$ImageUrl
    )

    try {
        $webClient = New-Object System.Net.WebClient
        $imageBytes = $webClient.DownloadData($ImageUrl)
        $base64 = [System.Convert]::ToBase64String($imageBytes)
        return $base64
    }
    catch {
        Write-RjRbLog -Message "Error downloading image from $ImageUrl : $_" -Verbose
        return $null
    }
    finally {
        if ($null -ne $webClient) {
            $webClient.Dispose()
        }
    }
}

# Initialize counters
$totalApps = 0
$updatedApps = 0
$skippedApps = 0
$failedApps = 0

# Get all Microsoft Store Apps (new)
Write-RjRbLog -Message "Fetching Store apps from Intune" -Verbose
$StoreApps = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps" -OdFilter "isof('microsoft.graph.winGetApp')" -Beta

"## Microsoft Store Apps in Intune:"
foreach ($app in $StoreApps) {
    "- $($app.displayName) (PackageIdentifier: $($app.packageIdentifier))"
    $totalApps++
}

"" # Empty line for better readability

# Process each app
foreach ($app in $StoreApps) {
    Write-RjRbLog -Message "Processing $($app.displayName)..." -Verbose

    # Check if the app already has a logo
    $appDetails = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps/$($app.id)" -UriQueryRaw '$expand=categories' -Beta

    if ($appDetails.largeIcon -and $appDetails.largeIcon.value) {
        "## [$($app.displayName)] Already has a logo. Skipping..."
        $skippedApps++
        continue
    }

    $storeUrl = "https://apps.microsoft.com/detail/$($app.packageIdentifier)"

    try {
        $response = Invoke-WebRequest -Uri $storeUrl -UseBasicParsing
        $html = $response.Content

        # Extract image URL using regex
        $imgPattern = '"iconUrl":"(https://store-images\.s-microsoft\.com/[^"]+)"'
        $imgMatch = [regex]::Match($html, $imgPattern)

        if ($imgMatch.Success) {
            $imageUrl = $imgMatch.Groups[1].Value
            Write-RjRbLog -Message "Found image URL: $imageUrl" -Verbose

            # Get base64 encoded image
            $base64Image = Get-Base64EncodedImage -ImageUrl $imageUrl

            # Prepare the update payload
            $updatePayload = @{
                "@odata.type" = "#microsoft.graph.winGetApp"
                largeIcon     = @{
                    "@odata.type" = "#microsoft.graph.mimeContent"
                    "type"        = "image/png"
                    "value"       = $base64Image
                }
            }

            # Update the app
            Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps/$($app.id)" -Method Patch -Body $updatePayload -Beta
            "## [$($app.displayName)] Successfully updated logo"
            $updatedApps++
        }
        else {
            "## [$($app.displayName)] No logo found"
            $failedApps++
        }
    }
    catch {
        Write-RjRbLog -Message "Error processing $($app.displayName): $_" -Verbose
        "## [$($app.displayName)] Failed to update logo: $_"
        $failedApps++
    }

    "" # Empty line for better readability
}

"## Logo Update Process Summary:"
"- Total apps processed: $totalApps"
"- Apps updated: $updatedApps"
"- Apps skipped (already had logo): $skippedApps"
"- Apps failed to update: $failedApps"
