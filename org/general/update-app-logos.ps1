<#
  .SYNOPSIS
  Update logos of Microsoft Store Apps (new) in Intune.

  .DESCRIPTION
  This script updates the logos for Microsoft Store Apps (new) by fetching them from the Microsoft Store.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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

# Get all Microsoft Store Apps (new)
Write-RjRbLog -Message "Fetching Store apps from Intune" -Verbose
$StoreApps = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps" -OdFilter "isof('microsoft.graph.winGetApp')" -Beta

"## Store Apps in Intune:"
foreach ($app in $StoreApps) {
    "DisplayName: $($app.displayName)"
    "PackageIdentifier: $($app.packageIdentifier)"
    "---"
}

# Process each app
foreach ($app in $StoreApps) {
    Write-RjRbLog -Message "Processing $($app.displayName)..." -Verbose
    
    # Check if the app already has a logo
    $appDetails = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps/'$($app.id)'" -UriQueryRaw '$expand=categories' -Beta

    if ($appDetails.largeIcon -and $appDetails.largeIcon.value) {
        "## App $($app.displayName) already has a logo. Skipping..."
        "---"
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
            "## Updated logo for $($app.displayName)"
        }
        else {
            "## No logo found for $($app.displayName)"
        }
    }
    catch {
        Write-RjRbLog -Message "Error processing $($app.displayName): $_" -Verbose
    }

    "---"
}

"## Logo update process completed."
