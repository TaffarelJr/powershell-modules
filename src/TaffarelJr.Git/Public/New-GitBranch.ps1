function New-GitBranch {
    <#
    .SYNOPSIS
        Creates a new branch.
    .PARAMETER Name
        The branch to create.
    .PARAMETER StartPoint
        Where the new branch starts. Defaults to HEAD.
    .PARAMETER Switch
        Also checks the new branch out. Without it, the branch is created
        but the current branch does not change.
    .PARAMETER RepoPath
        The repo to create it in. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$StartPoint,

        [switch]$Switch,

        [string]$RepoPath
    )

    $arguments = if ($Switch) {
        @('checkout', '-b', $Name)
    }
    else {
        @('branch', $Name)
    }

    if ($StartPoint) {
        $arguments += $StartPoint
    }

    Invoke-GitCommand -Activity "Creating branch $Name" -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
