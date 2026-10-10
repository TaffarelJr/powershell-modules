function Save-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Downloads a release's assets, or its source archive.
    .DESCRIPTION
        Without -Tag, the latest release is used, and gh then requires
        -Pattern or -Archive to say which files it means.
    .PARAMETER Tag
        The release's tag. Omit it for the latest release.
    .PARAMETER Pattern
        Glob patterns; only assets matching one are downloaded.
    .PARAMETER Archive
        Downloads the source code archive instead, as zip or tar.gz.
    .PARAMETER Destination
        The folder to download into. gh's default is the current
        directory.
    .PARAMETER Output
        A file to write a single asset to instead.
    .PARAMETER Clobber
        Overwrites a file that already exists.
    .PARAMETER SkipExisting
        Leaves a file that already exists alone.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Tag,

        [string[]]$Pattern,

        [ValidateSet('zip', 'tar.gz')]
        [string]$Archive,

        [string]$Destination,

        [string]$Output,

        [switch]$Clobber,

        [switch]$SkipExisting,

        [string]$Repository
    )

    $arguments = @('release', 'download')
    if ($Tag) {
        $arguments += $Tag
    }

    foreach ($glob in $Pattern) {
        $arguments += @('--pattern', $glob)
    }

    if ($Archive) {
        $arguments += @('--archive', $Archive)
    }

    if ($Destination) {
        $arguments += @('--dir', $Destination)
    }

    if ($Output) {
        $arguments += @('--output', $Output)
    }

    if ($Clobber) {
        $arguments += '--clobber'
    }

    if ($SkipExisting) {
        $arguments += '--skip-existing'
    }

    Invoke-GitHubCommand -Activity 'Downloading release assets' -Arguments $arguments -Repository $Repository | Out-Null
}
