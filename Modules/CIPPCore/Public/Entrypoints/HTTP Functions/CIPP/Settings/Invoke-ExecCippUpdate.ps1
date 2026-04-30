function Invoke-ExecCippUpdate {
    <#
    .SYNOPSIS
        Triggers an update for a CIPP component by syncing the GitHub fork with upstream and triggering deployment.
    .DESCRIPTION
        Delegates to Invoke-CIPPGitHubUpdate which uses the Azure ARM API to retrieve the connected source
        control repository and the GitHub extension PAT to sync the fork with the upstream KelvinTegelaar
        repository and trigger the deployment workflow via workflow_dispatch.
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
        $UpdateResult = Invoke-CIPPGitHubUpdate -Type $Type
        $ResultMessage = $UpdateResult.Message
        $ResultState = 'success'
        Write-LogMessage -headers $Request.Headers -API $APIName -message "Triggered update for CIPP $Type ($($UpdateResult.RepoPath))" -Sev 'Info'
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
