function Remove-GitFile {
    <#
    .SYNOPSIS
        Deletes a tracked file, staging the deletion in one step.
    .PARAMETER Path
        The file or folder to delete. Accepted from the pipeline, including
        by property name.
    .PARAMETER Recurse
        Required to delete a folder rather than a single file.
    .PARAMETER Force
        Deletes even a file with uncommitted changes. Without it, git
        refuses to lose that work.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [switch]$Recurse,

        [switch]$Force,

        [string]$RepoPath
    )

    process {
        $arguments = @('rm')
        if ($Recurse) {
            $arguments += '-r'
        }

        if ($Force) {
            $arguments += '-f'
        }

        $arguments += '--'
        $arguments += $Path
        Invoke-GitCommand -Activity "Deleting $($Path -join ', ')" -Arguments $arguments `
            -RepoPath $RepoPath | Out-Null
    }
}
