function Get-GitHubPullRequestDiff {
    <#
    .SYNOPSIS
        Returns a pull request's diff, or just the names of the files it
        changes.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER NameOnly
        Returns only the changed files' paths.
    .PARAMETER Patch
        Returns the diff in patch format.
    .PARAMETER Exclude
        Glob patterns, with forward slashes, for files to leave out.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        The diff's lines, or the file paths, always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [switch]$NameOnly,

        [switch]$Patch,

        [string[]]$Exclude,

        [string]$Repository
    )

    $arguments = @('pr', 'diff')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    if ($NameOnly) {
        $arguments += '--name-only'
    }

    if ($Patch) {
        $arguments += '--patch'
    }

    foreach ($pattern in $Exclude) {
        $arguments += @('--exclude', $pattern)
    }

    return Invoke-GitHubCommand -Activity 'Reading the pull request diff' -Arguments $arguments -Repository $Repository
}
