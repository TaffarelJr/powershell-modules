function Add-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Uploads files to a release as assets.
    .DESCRIPTION
        With -Clobber, an existing asset of the same name is deleted
        before the new one uploads - and stays gone if that upload then
        fails.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER Path
        The files to upload. Append '#Label' to a path to give the asset
        a display label.
    .PARAMETER Clobber
        Replaces an asset that already has the same name.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Tag,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string[]]$Path,

        [switch]$Clobber,

        [string]$Repository
    )

    process {
        $arguments = @('release', 'upload', $Tag) + @($Path)
        if ($Clobber) {
            $arguments += '--clobber'
        }

        Invoke-GitHubCommand -Activity "Uploading assets to release $Tag" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
