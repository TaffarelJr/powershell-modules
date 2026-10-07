function Remove-GitTag {
    <#
    .SYNOPSIS
        Deletes a local tag.
    .PARAMETER Name
        The tag to delete. Accepted from the pipeline, so a filtered list
        from Get-GitTag can be piped straight in.
    .PARAMETER RepoPath
        The repo to delete it from. Omit it to use the current working
        directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [string]$RepoPath
    )

    process {
        Invoke-GitCommand -Activity "Deleting tag $Name" `
            -Arguments @('tag', '-d', $Name) -RepoPath $RepoPath | Out-Null
    }
}
