function Clear-GitHubConfigCache {
    <#
    .SYNOPSIS
        Clears gh's own local CLI cache.
    .DESCRIPTION
        This is gh's own HTTP response cache (used by gh api -cache and
        similar), not anything stored on GitHub.
    #>
    param()

    Invoke-GitHubCommand -Activity "Clearing gh's cache" -Arguments @('config', 'clear-cache') | Out-Null
}
