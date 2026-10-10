function Remove-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Deletes one asset from a release.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER Name
        The asset's file name.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Tag,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string]$Name,

        [string]$Repository
    )

    process {
        $arguments = @('release', 'delete-asset', $Tag, $Name, '--yes')
        Invoke-GitHubCommand -Activity "Deleting asset $Name from release $Tag" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
