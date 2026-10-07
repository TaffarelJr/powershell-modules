function Update-GitBranch {
    <#
    .SYNOPSIS
        Pulls a branch from a remote: fetches it, then merges or rebases
        it onto the current branch.
    .PARAMETER Branch
        The remote branch to pull. Defaults to the current branch's name.
    .PARAMETER Remote
        The remote to pull from. Defaults to 'origin'.
    .PARAMETER Rebase
        Rebases local commits onto the fetched branch instead of merging.
    .PARAMETER RepoPath
        The repo to pull into. Omit it to use the current working
        directory.
    #>
    param(
        [string]$Branch,

        [string]$Remote = 'origin',

        [switch]$Rebase,

        [string]$RepoPath
    )

    $arguments = @('pull')
    if ($Rebase) {
        $arguments += '--rebase'
    }

    $arguments += $Remote
    if ($Branch) {
        $arguments += $Branch
    }

    Invoke-GitCommand -Activity 'Pulling' -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
