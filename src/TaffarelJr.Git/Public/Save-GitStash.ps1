function Save-GitStash {
    <#
    .SYNOPSIS
        Stashes uncommitted changes.
    .PARAMETER Message
        A label for the stash, shown by Get-GitStash.
    .PARAMETER IncludeUntracked
        Also stashes untracked files, which git otherwise leaves alone.
    .PARAMETER RepoPath
        The repo to stash in. Omit it to use the current working
        directory.
    #>
    param(
        [string]$Message,

        [switch]$IncludeUntracked,

        [string]$RepoPath
    )

    $arguments = @('stash', 'push')
    if ($IncludeUntracked) {
        $arguments += '-u'
    }

    if ($Message) {
        $arguments += @('-m', $Message)
    }

    Invoke-GitCommand -Activity 'Stashing changes' -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
