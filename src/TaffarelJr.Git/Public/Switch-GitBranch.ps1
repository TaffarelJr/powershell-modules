function Switch-GitBranch {
    <#
    .SYNOPSIS
        Checks out an existing branch, or creates and resets it from a
        start point with -Create.
    .PARAMETER Name
        The branch to check out.
    .PARAMETER Create
        Creates the branch if it does not exist, or resets it to
        -StartPoint if it does - git's own -B semantics. Without it,
        checking out a branch that does not exist throws.
    .PARAMETER StartPoint
        Where a -Create'd branch starts. Defaults to HEAD. Ignored without
        -Create.
    .PARAMETER RepoPath
        The repo to switch in. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [switch]$Create,

        [string]$StartPoint,

        [string]$RepoPath
    )

    $arguments = if ($Create) {
        @('checkout', '-B', $Name)
    }
    else {
        @('checkout', $Name)
    }

    if ($Create -and $StartPoint) {
        $arguments += $StartPoint
    }

    Invoke-GitCommand -Activity "Switching to $Name" -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
