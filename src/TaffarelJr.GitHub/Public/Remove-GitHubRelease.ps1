function Remove-GitHubRelease {
    <#
    .SYNOPSIS
        Deletes a release, and optionally its tag.
    .DESCRIPTION
        A published release in a repository with immutable releases
        cannot be deleted; a draft always can.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER CleanupTag
        Deletes the git tag as well as the release.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('TagName')]
        [string]$Tag,

        [switch]$CleanupTag,

        [string]$Repository
    )

    process {
        $arguments = @('release', 'delete', $Tag, '--yes')
        if ($CleanupTag) {
            $arguments += '--cleanup-tag'
        }

        Invoke-GitHubCommand -Activity "Deleting release $Tag" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
