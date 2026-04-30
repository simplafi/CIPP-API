function Start-CIPPAutoUpdateTimer {
    <#
    .SYNOPSIS
        Automatically updates CIPP components when a newer upstream version is available.
    .DESCRIPTION
        Compares the local API and frontend versions against the latest upstream releases.
        For any component that is out of date, calls Invoke-CIPPGitHubUpdate to sync the
        fork with upstream and trigger the deployment workflow. Requires the GitHub extension
        to be configured with a Personal Access Token that has 'repo' and 'workflow' scopes.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess('Start-CIPPAutoUpdateTimer', 'Starting CIPP Auto Update Timer')) {
        Write-Information 'Starting CIPP Auto Update Timer'

        $Version = Assert-CippVersion -CIPPVersion $null

        if (-not $Version.OutOfDateCIPPAPI -and -not $Version.OutOfDateCIPP) {
            Write-Information "CIPP is up to date (API: $($Version.LocalCIPPAPIVersion), CIPP: $($Version.LocalCIPPVersion)). No update required."
            return
        }

        if ($Version.OutOfDateCIPPAPI) {
            Write-Information "CIPP API is out of date (local: $($Version.LocalCIPPAPIVersion), remote: $($Version.RemoteCIPPAPIVersion)). Triggering auto-update."
            try {
                $Result = Invoke-CIPPGitHubUpdate -Type 'API'
                Write-LogMessage -API 'AutoUpdate' -message "CIPP API auto-update: $($Result.Message)" -Sev 'Info'
                Write-Information "CIPP API auto-update: $($Result.Message)"
            } catch {
                Write-LogMessage -API 'AutoUpdate' -message "CIPP API auto-update failed: $($_.Exception.Message)" -Sev 'Error' -LogData (Get-CippException -Exception $_)
                Write-Warning "CIPP API auto-update failed: $($_.Exception.Message)"
            }
        }

        if ($Version.OutOfDateCIPP) {
            Write-Information "CIPP frontend is out of date (local: $($Version.LocalCIPPVersion), remote: $($Version.RemoteCIPPVersion)). Triggering auto-update."
            try {
                $Result = Invoke-CIPPGitHubUpdate -Type 'CIPP'
                Write-LogMessage -API 'AutoUpdate' -message "CIPP frontend auto-update: $($Result.Message)" -Sev 'Info'
                Write-Information "CIPP frontend auto-update: $($Result.Message)"
            } catch {
                Write-LogMessage -API 'AutoUpdate' -message "CIPP frontend auto-update failed: $($_.Exception.Message)" -Sev 'Error' -LogData (Get-CippException -Exception $_)
                Write-Warning "CIPP frontend auto-update failed: $($_.Exception.Message)"
            }
        }
    }
}
