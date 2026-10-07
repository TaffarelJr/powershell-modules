function Remove-GitRemote {
    <#
    .SYNOPSIS
        Removes a remote, tolerating one that does not exist.
    .PARAMETER Name
        The remote to remove. Accepted from the pipeline.
    .PARAMETER RepoPath
        The repo to remove it from. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [string]$RepoPath
    )

    process {
        Invoke-GitCommand -Activity "Removing the $Name remote" `
            -Arguments @('remote', 'remove', $Name) -RepoPath $RepoPath -Tolerant | Out-Null
    }
}
