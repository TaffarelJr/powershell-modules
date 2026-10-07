function Test-GitChange {
    <#
    .SYNOPSIS
        Returns whether something changed - staged changes by default, or
        a path's difference between two refs.
    .PARAMETER FromRef
        The earlier ref to compare. Requires -ToRef.
    .PARAMETER ToRef
        The later ref to compare. Requires -FromRef.
    .PARAMETER Staged
        Checks staged changes instead of a ref range. This is already the
        default when neither -FromRef nor -ToRef is given.
    .PARAMETER Path
        Scopes the check to one path. Omit it to check the whole tree.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Staged')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [string]$FromRef,

        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [string]$ToRef,

        [Parameter(ParameterSetName = 'Staged')]
        [switch]$Staged,

        [string]$Path,

        [string]$RepoPath
    )

    $arguments = @('diff', '--quiet')
    if ($PSCmdlet.ParameterSetName -eq 'Staged') {
        $arguments += '--cached'
    }
    else {
        $arguments += @($FromRef, $ToRef)
    }

    if ($Path) {
        $arguments += @('--', $Path)
    }

    $read = Invoke-GitCommand -Activity 'Checking for changes' -Arguments $arguments -RepoPath $RepoPath -Tolerant
    return -not $read.Ok
}
