function Push-GitCommit {
    <#
    .SYNOPSIS
        Pushes a branch to a remote.
    .DESCRIPTION
        Success is read from --porcelain's machine-readable flag rather
        than git's summary line, which is localized.
    .PARAMETER Branch
        The branch to push. Defaults to the current branch.
    .PARAMETER Remote
        The remote to push to. Defaults to 'origin'.
    .PARAMETER SetUpstream
        Also sets the branch's upstream to this remote and branch.
    .PARAMETER Force
        Pushes even when the remote has commits this branch does not,
        using --force-with-lease: it still refuses if the remote moved
        since this branch last saw it, unlike a bare force push.
    .PARAMETER ForceWithoutLease
        A bare --force push, bypassing the lease check -Force applies.
        Only for a branch nothing else can be racing, such as one owned
        entirely by automation and recreated every run - it can silently
        discard someone else's work on a shared branch.
    .PARAMETER RepoPath
        The repo to push from. Omit it to use the current working
        directory.
    .OUTPUTS
        [bool] - whether anything was actually sent, as opposed to the
        remote already being up to date.
    #>
    param(
        [string]$Branch,

        [string]$Remote = 'origin',

        [switch]$SetUpstream,

        [switch]$Force,

        [switch]$ForceWithoutLease,

        [string]$RepoPath
    )

    $arguments = @('push', '--porcelain')
    if ($SetUpstream) {
        $arguments += '-u'
    }

    if ($ForceWithoutLease) {
        $arguments += '--force'
    }
    elseif ($Force) {
        $arguments += '--force-with-lease'
    }

    # Resolved explicitly rather than left for git to infer: 'push -u origin'
    # with no branch name fails outright, since -u has nothing to attach the
    # new upstream to even though a plain push would have inferred the
    # current branch from push.default.
    $branchName = if ($Branch) { $Branch } else { Get-GitBranch -RepoPath $RepoPath }
    $arguments += @($Remote, $branchName)

    $out = Invoke-GitCommand -Activity 'Pushing' -Arguments $arguments -RepoPath $RepoPath
    if (($out -join "`n") -match '(?m)^=\s') {
        return $false
    }

    return $true
}
