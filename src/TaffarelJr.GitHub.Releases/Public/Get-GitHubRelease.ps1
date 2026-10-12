function Get-GitHubRelease {
    <#
    .SYNOPSIS
        Returns one release, or lists a repository's releases.
    .DESCRIPTION
        Without -List, one release is described in full, assets included:
        the one tagged, or the latest. With -List, the repository's
        releases are returned newest first, with the summary fields gh
        offers for a listing.

        Each release carries the repository it was read from as Repository:
        the -Repository given, or else the repository in the release's Url,
        written OWNER/REPO, or HOST/OWNER/REPO for a host other than
        github.com, however it was named, so Where-Object Repository -EQ
        'OWNER/REPO' finds every release of that repository. A listing has
        no Url, so a listing of the current directory's repository carries
        $null. The functions that act on a release read it, so a release
        piped on is acted on where it came from, and one carrying $null in
        the current directory's repository.

        The default fields need gh 2.76 or later for one release, and 2.83
        or later for -List, for isImmutable. With an older gh, name the
        fields it has with -Property.
    .PARAMETER Tag
        The release's tag, or a release object, read by its TagName and
        Repository. Omit it for the latest release; an empty tag or $null
        throws rather than meaning the latest. Tags and releases can be
        piped in.
    .PARAMETER List
        Lists releases instead of describing one.
    .PARAMETER Limit
        The most releases to list, at least 1. gh's default is 30.
    .PARAMETER ExcludeDrafts
        Leaves drafts out of the list.
    .PARAMETER ExcludePreReleases
        Leaves pre-releases out of the list.
    .PARAMETER Order
        Lists oldest first (asc) or newest first (desc, gh's default).
    .PARAMETER Property
        The fields to return, as gh names them or as the result spells them
        (tagName or TagName); several may be given in one comma-separated
        value. Omit it for the default set. TagName is always added, and
        Url too for one release, so a release read this way can still be
        piped on to the functions that act on a release.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form, as a URL, or as a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A piped release's
        Repository binds to it, and a release given as -Tag in a different
        repository than this throws.
    .INPUTS
        System.Object
        A release's tag, or a release object, bound to -Tag. A piped
        release's Repository binds to -Repository.
    .OUTPUTS
        PSCustomObject
        Without -List, one object: TagName, Name, Body, IsDraft,
        IsPrerelease, IsImmutable, Assets, Author, TargetCommitish, Url,
        ApiUrl, UploadUrl, TarballUrl, ZipballUrl, CreatedAt, PublishedAt,
        Id, and DatabaseId. With -List, one object per release - TagName,
        Name, IsDraft, IsLatest, IsPrerelease, IsImmutable, CreatedAt,
        PublishedAt. Either way, plus Repository (OWNER/REPO, or
        HOST/OWNER/REPO off github.com; $null when not known).
    .EXAMPLE
        Get-GitHubRelease -Repository OWNER/REPO

        Returns the latest release of OWNER/REPO, in full.
    .EXAMPLE
        Get-GitHubRelease -Tag 'v1.2.0' -Repository OWNER/REPO

        Returns the release tagged v1.2.0 of OWNER/REPO, in full.
    .EXAMPLE
        Get-GitHubRelease -List -ExcludeDrafts -Repository OWNER/REPO |
            Get-GitHubRelease

        Describes every published release of OWNER/REPO that the listing
        holds, in full, each read from OWNER/REPO whatever the current
        directory is. Without -Limit, gh lists only its default 30.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Set-GitHubRelease
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View', ValueFromPipeline)]
        [Alias('TagName')]
        [object]$Tag,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [Parameter(ParameterSetName = 'List')]
        [switch]$ExcludeDrafts,

        [Parameter(ParameterSetName = 'List')]
        [switch]$ExcludePreReleases,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [string[]]$Property,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            Resolve-GitHubRepositoryArgument -Value $Repository -Given $given | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $repositoryReference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            if ($List) {
                $default = 'createdAt,isDraft,isImmutable,isLatest,isPrerelease,name,publishedAt,tagName'
                $fields = Join-GitHubReleaseField -Property $Property -Default $default -Required 'tagName'
                $arguments = @('release', 'list', '--json', $fields)
                if ($PSBoundParameters.ContainsKey('Limit')) {
                    $arguments += @('--limit', $Limit)
                }

                if ($ExcludeDrafts) {
                    $arguments += '--exclude-drafts'
                }

                if ($ExcludePreReleases) {
                    $arguments += '--exclude-pre-releases'
                }

                if ($Order) {
                    $arguments += @('--order', $Order.ToLowerInvariant())
                }

                $activity = 'Listing releases'
            }
            else {
                $default = 'apiUrl,assets,author,body,createdAt,databaseId,id,isDraft,isImmutable,isPrerelease,' +
                'name,publishedAt,tagName,tarballUrl,targetCommitish,uploadUrl,url,zipballUrl'
                $fields = Join-GitHubReleaseField -Property $Property -Default $default -Required 'tagName', 'url'
                $arguments = @('release', 'view', '--json', $fields)
                $activity = 'Reading the latest release'
                if ($PSBoundParameters.ContainsKey('Tag')) {
                    $lookup = @{
                        Release    = $Tag
                        Repository = $repositoryReference
                    }
                    $reference = ConvertTo-GitHubReleaseReference @lookup -PipelineBound
                    $repositoryReference = $reference.Repository
                    $arguments += @('--', $reference.Tag)
                    $activity = "Reading release $($reference.Tag)"
                }
            }

            $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference
            $releases = ConvertFrom-GitHubJson -Lines $out
            foreach ($release in $releases) {
                $origin = $repositoryReference
                $url = $release.PSObject.Properties['Url']
                $pattern = '^(?<repository>https?://[^/]+/[^/]+/[^/]+)/releases/'
                if (-not $origin -and $url -and "$($url.Value)" -match $pattern) {
                    $origin = $Matches['repository']
                }

                if ($origin) {
                    $origin = Format-GitHubRepositoryName -Repository $origin
                }

                $release | Add-Member -NotePropertyName 'Repository' -NotePropertyValue $origin
                $release
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
