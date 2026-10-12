function New-GitHubFork {
    <#
    .SYNOPSIS
        Forks a repository.
    .DESCRIPTION
        Whether to clone the fork, and whether to add it as a git remote
        of the current directory's repository, are both stated explicitly
        on every call, so gh never has a question left to ask.
    .PARAMETER Repository
        The repository to fork, in [HOST/]OWNER/REPO form. Omit it to
        fork the current directory's repository.
    .PARAMETER Organization
        Creates the fork in this organization instead of under the
        authenticated user.
    .PARAMETER ForkName
        A different name for the fork.
    .PARAMETER DefaultBranchOnly
        Copies only the default branch into the fork.
    .PARAMETER Clone
        Clones the fork into the current directory.
    .PARAMETER Remote
        Adds the fork as a git remote of the current directory's
        repository.
    .PARAMETER RemoteName
        The name for that remote. gh's default is origin, renaming any
        existing origin to upstream.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Repository,

        [string]$Organization,

        [string]$ForkName,

        [switch]$DefaultBranchOnly,

        [switch]$Clone,

        [switch]$Remote,

        [string]$RemoteName
    )

    $arguments = @('repo', 'fork')
    if ($Repository) {
        $arguments += $Repository
    }

    $arguments += @("--clone=$($Clone.ToString().ToLowerInvariant())", "--remote=$($Remote.ToString().ToLowerInvariant())")
    if ($Organization) {
        $arguments += @('--org', $Organization)
    }

    if ($ForkName) {
        $arguments += @('--fork-name', $ForkName)
    }

    if ($DefaultBranchOnly) {
        $arguments += '--default-branch-only'
    }

    if ($RemoteName) {
        $arguments += @('--remote-name', $RemoteName)
    }

    Invoke-GitHubCommand -Activity 'Forking the repository' -Arguments $arguments | Out-Null
}
