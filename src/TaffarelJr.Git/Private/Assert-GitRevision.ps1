function Assert-GitRevision {
    <#
    .SYNOPSIS
        Throws when a revision names no commit, or with -AnyObject nothing at
        all, in the repository.
    .DESCRIPTION
        For a command that git would refuse for the same reason, so that
        -WhatIf refuses it too. Run it after Get-GitRepoLocation, which
        has already said whether there is a repository to read.
    .PARAMETER Revision
        A branch, tag, HEAD, or any other git revision expression.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER AnyObject
        Accepts a revision that names a tree or a blob as well as a commit,
        as git tag does.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Revision,

        [Parameter(Mandatory)]
        [string]$Activity,

        [switch]$AnyObject,

        [string]$RepoPath
    )

    $expression = if ($AnyObject) { $Revision } else { "$Revision^{commit}" }
    $read = Invoke-GitCommand -Activity $Activity `
        -Arguments @('rev-parse', '--verify', '--quiet', $expression) -RepoPath $RepoPath -Tolerant
    if ($read.Ok) {
        return
    }

    $what = if ($AnyObject) { 'a revision' } else { 'a commit' }
    throw "$Activity failed: '$Revision' does not name $what."
}
