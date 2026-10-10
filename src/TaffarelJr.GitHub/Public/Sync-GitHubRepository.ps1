function Sync-GitHubRepository {
    <#
    .SYNOPSIS
        Brings a repository's branch up to date with its source
        repository's.
    .DESCRIPTION
        Fast-forwards the destination's branch to match the source's -
        by default a fork from its parent. Where the branches have
        diverged, only -Force reconciles them, by hard-resetting the
        destination.
    .PARAMETER Destination
        The repository to update, in [HOST/]OWNER/REPO form. Omit it to
        update the current directory's local repository.
    .PARAMETER Source
        The repository to update from. Omit it for the destination's
        parent.
    .PARAMETER Branch
        The branch to sync. Omit it for the source's default branch.
    .PARAMETER Force
        Hard-resets the destination branch to the source's when they have
        diverged.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Destination,

        [string]$Source,

        [string]$Branch,

        [switch]$Force
    )

    $arguments = @('repo', 'sync')
    if ($Destination) {
        $arguments += $Destination
    }

    if ($Source) {
        $arguments += @('--source', $Source)
    }

    if ($Branch) {
        $arguments += @('--branch', $Branch)
    }

    if ($Force) {
        $arguments += '--force'
    }

    Invoke-GitHubCommand -Activity 'Syncing the repository' -Arguments $arguments | Out-Null
}
