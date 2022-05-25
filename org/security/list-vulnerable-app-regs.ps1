<#
  .SYNOPSIS
  List all app registrations that suffer from the CVE-2021-42306 vulnerability.

  .DESCRIPTION
  List all app registrations that suffer from the CVE-2021-42306 vulnerability.

  .NOTES
  Permissions
   MS Graph (API): 
   - DeviceManagementManagedDevices.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

$appregs = Invoke-RjRbRestMethodGraph -Resource "/applications" -OdSelect "displayName,id,appId,createdDateTime,keyCredentials" -FollowPaging

foreach ($appreg in $appregs) {
    $appreg
    if ($appreg.displayName) {
        $DisplayName = $appreg.displayName
    }
    else {
        $DisplayName = $appreg.Id
    }
    $appID = $appReg.Id

    #Write-Verbose "Trying - $displayName"
    foreach ($cred in $appReg.keyCredentials) {
        if ($cred.Key.Length -gt 2000) {
            $outputBase = "$PWD\$appID"
            $outputFile = "$PWD\$appID.pfx"
            $iter = 1

            while (Test-Path $outputFile) {                    
                $outputFile = ( -join ($outputBase, '-', ([string]$iter), '.pfx'))
                $iter += 1
                Write-Verbose "`tMultiple Creds - Trying $outputFile"
            }
            [IO.File]::WriteAllBytes($outputFile, [Convert]::FromBase64String($cred.Key))
            $certResults = Get-PfxData $outputFile
        
            $ErrorActionPreference = 'SilentlyContinue'
            if ($null -ne $certResults) {
                Write-Verbose "`t$displayName - $appID - has a stored pfx credential"    
                "$displayName `t $appID" | Out-File -Append "$PWD\AffectedAppRegistrations.txt"
            }
            else {
                Remove-Item $outputFile | Out-Null
            }
        }
    }
}