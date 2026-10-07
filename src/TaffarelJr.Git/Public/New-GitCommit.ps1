function New-GitCommit {
    <#
    .SYNOPSIS
        Commits staged changes.
    .PARAMETER Message
        The commit message. Required unless -Amend and -NoEdit are both
        set, which keeps the amended commit's existing message.
    .PARAMETER Amend
        Folds staged changes into the previous commit instead of creating
        a new one.
    .PARAMETER AllowEmpty
        Commits even when nothing is staged. For a deliberate marker
        commit; without it, an empty commit throws.
    .PARAMETER NoEdit
        Never opens an interactive editor. Required to be meaningful on
        its own outside of -Amend; combine with -Amend to keep that
        commit's existing message unchanged.
    .PARAMETER RepoPath
        The repo to commit in. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [switch]$Amend,

        [switch]$AllowEmpty,

        [switch]$NoEdit,

        [string]$RepoPath
    )

    if (-not $Message -and -not ($Amend -and $NoEdit)) {
        throw 'New-GitCommit: -Message is required unless both -Amend and -NoEdit are set.'
    }

    $arguments = @('commit')
    if ($Amend) {
        $arguments += '--amend'
    }

    if ($AllowEmpty) {
        $arguments += '--allow-empty'
    }

    if ($NoEdit) {
        $arguments += '--no-edit'
    }

    if ($Message) {
        $arguments += @('-m', $Message)
    }

    Invoke-GitCommand -Activity 'Committing' -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
