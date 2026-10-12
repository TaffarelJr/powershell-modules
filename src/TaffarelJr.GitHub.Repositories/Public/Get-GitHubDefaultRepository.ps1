function Get-GitHubDefaultRepository {
    <#
    .SYNOPSIS
        Returns the repository gh treats as the default for the current
        directory's clone, or $null when none is set.
    .OUTPUTS
        The default repository as OWNER/REPO, or $null.
    #>
    param()

    $result = Invoke-GitHubCommand -Activity 'Reading the default repository' -Arguments @('repo', 'set-default', '--view') -Tolerant
    if (-not $result.Ok -or $result.Output.Count -eq 0) {
        return $null
    }

    return $result.Output[0]
}
