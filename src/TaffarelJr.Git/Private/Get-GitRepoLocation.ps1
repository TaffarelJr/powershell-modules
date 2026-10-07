using namespace System.IO

function Get-GitRepoLocation {
    <#
    .SYNOPSIS
        Returns the root of the repository a command acts in, or throws when
        there is none.
    .DESCRIPTION
        The root is the top of the working tree, as a full path with the
        platform's own separators, for a -WhatIf or -Confirm message to name.
        With -AllowBare, a bare repository, which has no working tree, is
        accepted too, and its git directory is the root. A folder that is no
        repository, or does not exist, throws, with git's own reason; so does
        a repository git refuses because another user owns it.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed". A
        credential a URL in it carries is hidden in the message.
    .PARAMETER RepoPath
        The -RepoPath the command was given. A relative path or a PowerShell
        drive is resolved against PowerShell's current location, as
        Invoke-GitCommand resolves it. Omit it for the current location.
    .PARAMETER AllowBare
        Accepts a bare repository, for a command that needs no working tree.
    .OUTPUTS
        The root's full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [string]$RepoPath,

        [switch]$AllowBare
    )

    $arguments = @('rev-parse', '--show-toplevel')
    $read = Invoke-GitCommand -Activity $Activity -Arguments $arguments -RepoPath $RepoPath -Tolerant
    $kind = 'git working tree'
    if (-not $read.Ok -and $AllowBare) {
        $arguments = @('rev-parse', '--absolute-git-dir')
        $read = Invoke-GitCommand -Activity $Activity -Arguments $arguments -RepoPath $RepoPath -Tolerant
        $kind = 'git repository'
    }

    if ($read.Ok) {
        return [Path]::GetFullPath(($read.Output -join '').Trim())
    }

    $shownActivity = Hide-UrlCredential -Text $Activity
    Assert-GitOwnershipTrusted -Activity $shownActivity -Arguments $arguments -Message $read.Message `
        -RepoPath $RepoPath
    $where = if ($RepoPath) { "'$RepoPath'" } else { 'the current folder' }
    throw "$shownActivity failed: $where is not inside a $kind ($($read.Message))."
}
