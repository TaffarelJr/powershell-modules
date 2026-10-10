function Get-GitHubRelease {
    <#
    .SYNOPSIS
        Returns one release, or lists a repository's releases.
    .DESCRIPTION
        Without -List, one release is described in full, assets included:
        the one tagged, or the latest. With -List, the repository's
        releases are returned newest first, with the summary fields gh
        offers for a listing.
    .PARAMETER Tag
        The release's tag. Omit it for the latest release.
    .PARAMETER List
        Lists releases instead of describing one.
    .PARAMETER Limit
        The most releases to list. gh's default is 30.
    .PARAMETER ExcludeDrafts
        Leaves drafts out of the list.
    .PARAMETER ExcludePreReleases
        Leaves pre-releases out of the list.
    .PARAMETER Order
        Lists oldest first (asc) or newest first (desc, gh's default).
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        Without -List, one object: TagName, Name, Body, IsDraft,
        IsPrerelease, IsImmutable, Assets, Author, TargetCommitish, Url,
        TarballUrl, ZipballUrl, CreatedAt, PublishedAt, and ids. With
        -List, one object per release - TagName, Name, IsDraft, IsLatest,
        IsPrerelease, IsImmutable, CreatedAt, PublishedAt - always an
        array.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View')]
        [string]$Tag,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [int]$Limit,

        [Parameter(ParameterSetName = 'List')]
        [switch]$ExcludeDrafts,

        [Parameter(ParameterSetName = 'List')]
        [switch]$ExcludePreReleases,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [string]$Repository
    )

    if (-not $List) {
        $arguments = @('release', 'view')
        if ($Tag) {
            $arguments += $Tag
        }

        $arguments += @('--json', 'apiUrl,assets,author,body,createdAt,databaseId,id,isDraft,isImmutable,isPrerelease,name,publishedAt,tagName,tarballUrl,targetCommitish,uploadUrl,url,zipballUrl')
        $out = Invoke-GitHubCommand -Activity 'Reading the release' -Arguments $arguments -Repository $Repository
        return ConvertFrom-GitHubJson -Lines $out
    }

    $arguments = @('release', 'list', '--json', 'createdAt,isDraft,isImmutable,isLatest,isPrerelease,name,publishedAt,tagName')
    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    if ($ExcludeDrafts) {
        $arguments += '--exclude-drafts'
    }

    if ($ExcludePreReleases) {
        $arguments += '--exclude-pre-releases'
    }

    if ($Order) {
        $arguments += @('--order', $Order)
    }

    $out = Invoke-GitHubCommand -Activity 'Listing releases' -Arguments $arguments -Repository $Repository
    $releases = ConvertFrom-GitHubJson -Lines $out
    return , @($releases)
}
