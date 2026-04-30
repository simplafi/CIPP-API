function Invoke-CIPPGitHubUpdate {
    <#
    .SYNOPSIS
        Syncs a CIPP component's GitHub fork with the upstream repository and triggers deployment.
    .DESCRIPTION
        Uses the Azure ARM API to retrieve the connected source control repository for the Function App
        or Static Web App, then calls the GitHub API to sync the fork's branch with the upstream
        KelvinTegelaar repository and triggers the deployment workflow via workflow_dispatch.
        Requires the GitHub extension to be configured with a Personal Access Token that has
        'repo' and 'workflow' scopes.
    .PARAMETER Type
        The component to update. Valid values are 'API' (Function App) or 'CIPP' (Static Web App frontend).
    .EXAMPLE
        Invoke-CIPPGitHubUpdate -Type 'API'
    .EXAMPLE
        Invoke-CIPPGitHubUpdate -Type 'CIPP'
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('API', 'CIPP')]
        [string]$Type = 'API'
    )

    # Verify GitHub extension is enabled
    $ExtTable = Get-CIPPTable -TableName Extensionsconfig
    $ExtensionConfig = (Get-CIPPAzDataTableEntity @ExtTable).config
    if ($ExtensionConfig -and (Test-Json -Json $ExtensionConfig)) {
        $GitHubConfig = ($ExtensionConfig | ConvertFrom-Json).GitHub
    } else {
        $GitHubConfig = @{ Enabled = $false }
    }

    if (-not $GitHubConfig.Enabled) {
        throw 'The GitHub extension is not enabled. Please enable it under Settings > Extensions > GitHub to use auto-update.'
    }

    $GitHubAPIKey = Get-ExtensionAPIKey -Extension 'GitHub'
    if (-not $GitHubAPIKey) {
        throw 'No GitHub Personal Access Token found. Please provide a PAT with "repo" and "workflow" scopes under Settings > Extensions > GitHub.'
    }

    # Resolve Azure resource identifiers from environment
    $SubscriptionId = Get-CIPPAzFunctionAppSubId
    $ResourceGroup = $env:WEBSITE_RESOURCE_GROUP
    if (-not $ResourceGroup) {
        # WEBSITE_OWNER_NAME format: {subscriptionId}+{resourceGroup}-{region}webspace[-Linux]
        $Owner = $env:WEBSITE_OWNER_NAME
        if ($Owner -match '^(?<SubscriptionId>[^+]+)\+(?<RGName>[^-]+(?:-[^-]+)*?)(?:-[^-]+webspace(?:-Linux)?)?$') {
            $ResourceGroup = $Matches.RGName
        }
    }
    if (-not $ResourceGroup) {
        throw 'Could not determine the Azure Resource Group. Ensure the Function App has the WEBSITE_RESOURCE_GROUP environment variable set.'
    }

    # Fetch source control configuration from Azure ARM
    if ($Type -eq 'API') {
        $FunctionAppName = $env:WEBSITE_SITE_NAME
        $SourceControlUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FunctionAppName/sourcecontrols/web?api-version=2022-03-01"
        $SourceControl = New-CIPPAzRestRequest -Uri $SourceControlUri -Method GET

        $RepoUrl = $SourceControl.properties.repoUrl
        $Branch = $SourceControl.properties.branch ?? 'main'
        $WorkflowFile = 'azure-function.yml'
    } else {
        # Replace only the leading 'cipp' prefix (case-insensitive) to form the SWA name
        $SWAName = $env:WEBSITE_SITE_NAME -replace '(?i)^cipp', 'CIPP-SWA'
        $SWAUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/staticSites/$SWAName?api-version=2022-03-01"
        $SWA = New-CIPPAzRestRequest -Uri $SWAUri -Method GET

        $RepoUrl = $SWA.properties.repositoryUrl
        $Branch = $SWA.properties.branch ?? 'main'
        $WorkflowFile = 'azure-static-web-apps.yml'
    }

    if (-not $RepoUrl) {
        throw "No source control repository found for CIPP $Type. Please ensure GitHub Actions deployment is configured."
    }

    # Validate and parse owner/repo from the repository URL
    try {
        $RepoPath = ([uri]$RepoUrl).LocalPath.TrimStart('/')
        if ($RepoPath -notmatch '^[^/]+/[^/]+$') {
            throw "Unexpected repository path format: '$RepoPath'"
        }
    } catch {
        throw "Invalid repository URL '$RepoUrl': $($_.Exception.Message)"
    }

    # Sync fork branch with upstream repository
    try {
        $SyncResult = Invoke-GitHubApiRequest -Path "repos/$RepoPath/merge-upstream" -Method POST -Body @{ branch = $Branch }
    } catch {
        throw "Failed to sync CIPP $Type fork with upstream: $($_.Exception.Message)"
    }

    if ($SyncResult.merge_type -eq 'none') {
        $SyncMessage = "CIPP $Type is already up to date with upstream (no changes to merge)."
    } else {
        $SyncMessage = "Successfully synced CIPP $Type fork with upstream ($($SyncResult.merge_type))."
    }

    # Trigger workflow_dispatch to start the deployment pipeline
    $DeployMessage = $null
    try {
        Invoke-GitHubApiRequest -Path "repos/$RepoPath/actions/workflows/$WorkflowFile/dispatches" -Method POST -Body @{ ref = $Branch } | Out-Null
        $DeployMessage = 'Deployment workflow triggered successfully. The update will be live shortly.'
    } catch {
        $DeployMessage = "Fork synced, but failed to trigger the deployment workflow automatically: $($_.Exception.Message). You can trigger it manually from your GitHub Actions page."
    }

    return [PSCustomObject]@{
        Type        = $Type
        RepoPath    = $RepoPath
        Branch      = $Branch
        MergeType   = $SyncResult.merge_type
        SyncMessage = $SyncMessage
        DeployMessage = $DeployMessage
        Message     = "$SyncMessage $DeployMessage"
    }
}
