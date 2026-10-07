function Remove-GitBranch {
    <#
    .SYNOPSIS
        Deletes a local branch.
    .PARAMETER Name
        The branch to delete. Accepted from the pipeline, so a filtered
        list from Get-GitBranch -List can be piped straight in.
    .PARAMETER Force
        Deletes it even if it is not fully merged. Without it, git refuses
        an unmerged branch rather than risk losing commits.
    .PARAMETER RepoPath
        The repo to delete it from. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [switch]$Force,

        [string]$RepoPath
    )

    process {
        $flag = if ($Force) { '-D' } else { '-d' }
        Invoke-GitCommand -Activity "Deleting branch $Name" `
            -Arguments @('branch', $flag, $Name) -RepoPath $RepoPath | Out-Null
    }
}
