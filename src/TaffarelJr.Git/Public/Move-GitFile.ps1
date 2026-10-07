function Move-GitFile {
    <#
    .SYNOPSIS
        Renames or moves a tracked file, staging the rename in one step.
    .DESCRIPTION
        Tracked as a rename from the start, unlike a plain filesystem move
        followed by Add-GitChange - which stages a delete and an add, and
        leaves git to GUESS at the rename only when the content is similar
        enough, which it does not always get right.
    .PARAMETER Path
        The file's current path.
    .PARAMETER Destination
        Its new path.
    .PARAMETER Force
        Overwrites -Destination if it already exists.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$Destination,

        [switch]$Force,

        [string]$RepoPath
    )

    $arguments = @('mv')
    if ($Force) {
        $arguments += '-f'
    }

    $arguments += @($Path, $Destination)
    Invoke-GitCommand -Activity "Renaming $Path" -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
