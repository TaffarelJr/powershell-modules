function Test-GitPath {
    <#
    .SYNOPSIS
        Returns whether a path exists in git, either currently tracked or
        at a specific historical ref.
    .PARAMETER Path
        The path to check, relative to the repo root.
    .PARAMETER Ref
        A historical ref to check the path at, instead of the current
        index. Omit it to check whether the path is tracked right now.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [string]$Ref,

        [string]$RepoPath
    )

    if ($Ref) {
        $read = Invoke-GitCommand -Activity "Checking $Path at $Ref" `
            -Arguments @('cat-file', '-e', "${Ref}:${Path}") -RepoPath $RepoPath -Tolerant
        return $read.Ok
    }

    $read = Invoke-GitCommand -Activity "Checking $Path" `
        -Arguments @('ls-files', '--error-unmatch', '--', $Path) -RepoPath $RepoPath -Tolerant
    return $read.Ok
}
