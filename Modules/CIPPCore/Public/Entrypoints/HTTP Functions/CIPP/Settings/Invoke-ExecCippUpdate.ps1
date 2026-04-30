function Invoke-ExecCippUpdate {
    <#
    .SYNOPSIS
        Triggers an update for a CIPP component by syncing the GitHub fork with upstream and triggering deployment.
    .DESCRIPTION
        Uses the Azure ARM API to retrieve the connected source control repository for the Function App or
        Static Web App, then calls the GitHub API to sync the fork with the upstream KelvinTegelaar repository
        and triggers the deployment workflow via workflow_dispatch. Requires the GitHub extension to be
        configured with a Personal Access Token that has 'repo' and 'workflow' scopes.
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.AppSettings.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Type = $Request.Query.Type ?? $Request.Body.Type ?? 'API'

    try {
        # Verify GitHub extension is configured with a PAT
        $ExtTable = Get-CIPPTable -TableName Extensionsconfig
        $ExtensionConfig = (Get-CIPPAzDataTableEntity @ExtTable).config
        if ($ExtensionConfig -and (Test-Json -Json $ExtensionConfig)) {
            $GitHubConfig = ($ExtensionConfig | ConvertFrom-Json).GitHub
        } else {
            $GitHubConfig = @{ Enabled = $false }
        }

        if (-not $GitHubConfig.Enabled) {
            throw 'The GitHub extension is not enabled. Please enable it under Settings > Extensions > GitHub to use the update button.'
        }

        $GitHubAPIKey = Get-ExtensionAPIKey -Extension 'GitHub'
        if (-not $GitHubAPIKey) {
            throw 'No GitHub Personal Access Token found. Please provide a PAT with "repo" and "workflow" scopes under Settings > Extensions > GitHub.'
        }

        $SubscriptionId = Get-CIPPAzFunctionAppSubId
        $ResourceGroup = $env:WEBSITE_RESOURCE_GROUP
        if (-not $ResourceGroup) {
            $Owner = $env:WEBSITE_OWNER_NAME
            # WEBSITE_OWNER_NAME format: {subscriptionId}+{resourceGroup}-{region}webspace[-Linux]
            if ($Owner -match '^(?<SubscriptionId>[^+]+)\+(?<RGName>[^-]+(?:-[^-]+)*?)(?:-[^-]+webspace(?:-Linux)?)?$') {
                $ResourceGroup = $Matches.RGName
            }
        }
        if (-not $ResourceGroup) {
            throw 'Could not determine the Azure Resource Group. Ensure the Function App has the WEBSITE_RESOURCE_GROUP environment variable set.'
        }

        if ($Type -eq 'API') {
            $FunctionAppName = $env:WEBSITE_SITE_NAME
            $SourceControlUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FunctionAppName/sourcecontrols/web?api-version=2022-03-01"
            $SourceControl = New-CIPPAzRestRequest -Uri $SourceControlUri -Method GET

            $RepoUrl = $SourceControl.properties.repoUrl
            $Branch = $SourceControl.properties.branch ?? 'main'
            $WorkflowFile = 'azure-function.yml'
        } else {
            $SWAName = $env:WEBSITE_SITE_NAME -replace '(?i)cipp', 'CIPP-SWA-'
            $SWAUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/staticSites/$SWAName?api-version=2022-03-01"
            $SWA = New-CIPPAzRestRequest -Uri $SWAUri -Method GET

            $RepoUrl = $SWA.properties.repositoryUrl
            $Branch = $SWA.properties.branch ?? 'main'
            $WorkflowFile = 'azure-static-web-apps.yml'
        }

        if (-not $RepoUrl) {
            throw "No source control repository found for CIPP $Type. Please ensure GitHub Actions deployment is configured."
        }

        $RepoPath = ([uri]$RepoUrl).LocalPath.TrimStart('/')

        # Sync fork with upstream repository
        $SyncResult = Invoke-GitHubApiRequest -Path "repos/$RepoPath/merge-upstream" -Method POST -Body @{ branch = $Branch }

        if ($SyncResult.merge_type -eq 'none') {
            $SyncMessage = "CIPP $Type is already up to date with upstream (no changes to merge)."
        } else {
            $SyncMessage = "Successfully synced CIPP $Type fork with upstream ($($SyncResult.merge_type))."
        }

        # Trigger workflow_dispatch to kick off the deployment workflow
        try {
            Invoke-GitHubApiRequest -Path "repos/$RepoPath/actions/workflows/$WorkflowFile/dispatches" -Method POST -Body @{ ref = $Branch } | Out-Null
            $DeployMessage = "Deployment workflow triggered successfully. The update will be live shortly."
        } catch {
            $DeployMessage = "Fork synced, but failed to trigger the deployment workflow automatically: $($_.Exception.Message). You can trigger it manually from your GitHub Actions page."
        }

        $ResultMessage = "$SyncMessage $DeployMessage"
        $ResultState = 'success'
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Triggered update for CIPP $Type from $RepoUrl" -Sev 'Info'

    } catch {
        $ResultMessage = "Failed to update CIPP $Type`: $($_.Exception.Message)"
        $ResultState = 'error'
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Failed to trigger update for CIPP $Type`: $($_.Exception.Message)" -Sev 'Error' -LogData (Get-CippException -Exception $_)
    }

    $Body = @{
        Results = @{
            resultText = $ResultMessage
            state      = $ResultState
        }
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Body
        })
}
