function Assert-CippVersion {
    <#
    .SYNOPSIS
    Compare the local version of CIPP with the latest version.

    .DESCRIPTION
    Retrieves the local version of CIPP and compares it with the latest version in GitHub.

    .PARAMETER CIPPVersion
    Local version of CIPP frontend

    #>
    param($CIPPVersion)
    
    if (-not $CIPPVersion) {
        try {
            $SubscriptionId = Get-CIPPAzFunctionAppSubId
            $ResourceGroup = $env:WEBSITE_RESOURCE_GROUP
            if (-not $ResourceGroup) {
                $Owner = $env:WEBSITE_OWNER_NAME
                if ($Owner -match '^(?<SubscriptionId>[^+]+)\+(?<RGName>[^-]+(?:-[^-]+)*?)(?:-[^-]+webspace(?:-Linux)?)?$') {
                    $ResourceGroup = $Matches.RGName
                }
            }
            if ($ResourceGroup) {
                $SWAName = $env:WEBSITE_SITE_NAME -replace '(?i)^cipp', 'CIPP-SWA'
                $SWAUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/staticSites/$SWAName?api-version=2022-03-01"
                $SWA = New-CIPPAzRestRequest -Uri $SWAUri -Method GET
                if ($SWA.properties.defaultHostname) {
                    $CIPPVersion = (Invoke-RestMethod -Uri "https://$($SWA.properties.defaultHostname)/version.json" -ErrorAction Stop).version
                }
            }
        } catch {
            Write-Warning "Could not retrieve local CIPP frontend version: $($_.Exception.Message)"
        }
    }

    $CIPPCoreModuleRoot = Get-Module -Name CIPPCore | Select-Object -ExpandProperty ModuleBase
    $CIPPRoot = (Get-Item $CIPPCoreModuleRoot).Parent.Parent
    $APIVersion = (Get-Content -Path $CIPPRoot\version_latest.txt).trim()

    $RemoteAPIVersion = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/KelvinTegelaar/CIPP-API/master/version_latest.txt').trim()
    $RemoteCIPPVersion = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/KelvinTegelaar/CIPP/main/public/version.json').version

    [PSCustomObject]@{
        LocalCIPPVersion     = $CIPPVersion
        RemoteCIPPVersion    = $RemoteCIPPVersion
        LocalCIPPAPIVersion  = $APIVersion
        RemoteCIPPAPIVersion = $RemoteAPIVersion
        OutOfDateCIPP        = ([semver]$RemoteCIPPVersion -gt [semver]$CIPPVersion)
        OutOfDateCIPPAPI     = ([semver]$RemoteAPIVersion -gt [semver]$APIVersion)
    }
}
