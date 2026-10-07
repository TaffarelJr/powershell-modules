function Assert-GitNameAvailable {
    <#
    .SYNOPSIS
        Throws when a new branch, tag or remote could not take a name: git
        would refuse it as malformed, or a branch or tag of that name
        already exists.
    .DESCRIPTION
        For a command that git would refuse for the same reason, so that
        -WhatIf refuses it too. A name is checked the way git checks it
        (git check-ref-format), so one with a space, '..' or a trailing
        '.lock', say, throws; so does HEAD for a branch, which git refuses
        though that check allows it.
    .PARAMETER Kind
        What the name is for: branch, tag or remote.
    .PARAMETER Name
        The name to check. A credential a URL in it carries is hidden in the
        message.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed". A
        credential a URL in it carries is hidden in the message.
    .PARAMETER MayExist
        Checks only the form of the name, for a command that also accepts
        one that exists: one that sets a remote, whose existence is not a
        ref git can look up.
    .PARAMETER Hint
        What the caller can do instead, added to the message when a branch
        or tag of that name already exists.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('branch', 'tag', 'remote')]
        [string]$Kind,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Activity,

        [switch]$MayExist,

        [string]$Hint,

        [string]$RepoPath
    )

    $ref = switch ($Kind) {
        'branch' { "refs/heads/$Name" }
        'tag' { "refs/tags/$Name" }
        'remote' { "refs/remotes/$Name/HEAD" }
    }

    $format = Invoke-GitCommand -Activity $Activity -Arguments @('check-ref-format', $ref) `
        -RepoPath $RepoPath -Tolerant
    $shownActivity = Hide-UrlCredential -Text $Activity
    $shownName = Hide-UrlCredential -Text $Name

    # check-ref-format allows refs/heads/HEAD, which git branch and checkout -b refuse.
    if (-not $format.Ok -or ($Kind -eq 'branch' -and $Name -ceq 'HEAD')) {
        throw "$shownActivity failed: '$shownName' is not a valid $Kind name."
    }

    if ($MayExist) {
        return
    }

    $exists = Invoke-GitCommand -Activity $Activity -Arguments @('show-ref', '--verify', '--quiet', $ref) `
        -RepoPath $RepoPath -Tolerant
    if ($exists.Ok) {
        $message = "$shownActivity failed: a $Kind named '$shownName' already exists."
        if ($Hint) {
            $message += " $Hint"
        }

        throw $message
    }
}
