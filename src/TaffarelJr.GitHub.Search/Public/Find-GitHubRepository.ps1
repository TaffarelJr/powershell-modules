function Find-GitHubRepository {
    <#
    .SYNOPSIS
        Searches GitHub for repositories.
    .DESCRIPTION
        Give a query, a filter, or both: with neither the search would
        cover all of GitHub, so that throws. A filter that is passed but
        empty or blank throws for the same reason, rather than being left
        out. A list value holding a comma throws too, as gh would split it
        into two filters: give each value on its own, and put a
        qualifier whose one value holds a comma in -Query, quoted
        (label:"a,b").
    .PARAMETER Query
        Search keywords, each one a separate value, or none to rely on the
        filters alone. A value with a space in it is searched as an exact
        phrase, so 'powershell module' is one phrase where 'powershell',
        'module' is two keywords. A qualifier such as topic:ci is a value
        of its own, and one starting with a dash excludes (-topic:ci).
    .PARAMETER Owner
        Only repositories owned by one of these users or organizations.
    .PARAMETER Language
        Only repositories whose primary language is this.
    .PARAMETER Topic
        Only repositories carrying every one of these topics.
    .PARAMETER License
        Only repositories under one of these license keywords.
    .PARAMETER Visibility
        Only repositories with one of these visibilities: public,
        private, or internal.
    .PARAMETER Archived
        Only archived repositories, or with -Archived:$false only the
        others.
    .PARAMETER IncludeForks
        Whether forks are included: false (gh's default), true, or only
        forks.
    .PARAMETER Stars
        A star-count range, such as '>100' or '10..50'.
    .PARAMETER Forks
        A fork-count range.
    .PARAMETER Followers
        A follower-count range.
    .PARAMETER Size
        A size range in kilobytes.
    .PARAMETER GoodFirstIssues
        A range on the number of issues labeled 'good first issue'.
    .PARAMETER HelpWantedIssues
        A range on the number of issues labeled 'help wanted'.
    .PARAMETER NumberTopics
        A range on the number of topics.
    .PARAMETER Created
        When the repository was created: a [datetime], or a date or range
        as text in YYYY-MM-DD form, such as '>2026-01-01' or
        '2026-01-01..2026-01-31'. A [datetime] or [datetimeoffset] must
        be a date with no time of day (give its .Date) and is sent as
        the day it shows; one with a time throws, as GitHub would match
        it to the exact second. For a moment, give text such as
        '>=2026-10-11T09:33:17Z'.
    .PARAMETER Updated
        When the repository was last pushed to, in the same forms as
        -Created. A change to its settings or description alone does not
        count.
    .PARAMETER Match
        Restricts the search to specific fields: name, description, or
        readme.
    .PARAMETER Sort
        Orders by forks, help-wanted-issues, stars, or updated. gh's
        default is best-match.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default). Only applies
        with -Sort.
    .PARAMETER Limit
        The most results to fetch, from 1 to 1000. gh's default is 30.
        GitHub returns at most 1000 results for any search.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per repository - Name, FullName, Owner, Description,
        Homepage, Url, Language, License, Visibility, DefaultBranch, Id,
        IsPrivate, IsArchived, IsDisabled, IsFork, HasDownloads, HasIssues,
        HasPages, HasProjects, HasWiki, StargazersCount, ForksCount,
        WatchersCount, OpenIssuesCount, Size, CreatedAt, PushedAt, and
        UpdatedAt.
    .EXAMPLE
        Find-GitHubRepository -Query 'github cli', '-topic:deprecated' `
            -Language Go

        Finds Go repositories holding the exact phrase "github cli", except
        those with the deprecated topic.
    .EXAMPLE
        Find-GitHubRepository -Owner 'cli' -Archived:$false -Sort stars

        Finds cli's repositories that are not archived, most stars first.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Search/README.md
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string[]]$Query,

        [string[]]$Owner,

        [string]$Language,

        [string[]]$Topic,

        [string[]]$License,

        [ValidateSet('public', 'private', 'internal')]
        [string[]]$Visibility,

        [switch]$Archived,

        [ValidateSet('false', 'true', 'only')]
        [string]$IncludeForks,

        [string]$Stars,

        [string]$Forks,

        [string]$Followers,

        [string]$Size,

        [string]$GoodFirstIssues,

        [string]$HelpWantedIssues,

        [string]$NumberTopics,

        [object]$Created,

        [object]$Updated,

        [ValidateSet('name', 'description', 'readme')]
        [string[]]$Match,

        [ValidateSet('forks', 'help-wanted-issues', 'stars', 'updated')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [ValidateRange(1, 1000)]
        [int]$Limit
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $flags = [ordered]@{
            Owner            = '--owner'
            Language         = '--language'
            Topic            = '--topic'
            License          = '--license'
            Visibility       = '--visibility'
            Archived         = '--archived'
            IncludeForks     = '--include-forks'
            Stars            = '--stars'
            Forks            = '--forks'
            Followers        = '--followers'
            Size             = '--size'
            GoodFirstIssues  = '--good-first-issues'
            HelpWantedIssues = '--help-wanted-issues'
            NumberTopics     = '--number-topics'
            Created          = '--created'
            Updated          = '--updated'
            Match            = '--match'
            Sort             = '--sort'
            Order            = '--order'
            Limit            = '--limit'
        }

        $fields = @(
            'createdAt', 'defaultBranch', 'description', 'forksCount', 'fullName', 'hasDownloads', 'hasIssues',
            'hasPages', 'hasProjects', 'hasWiki', 'homepage', 'id', 'isArchived', 'isDisabled', 'isFork', 'isPrivate',
            'language', 'license', 'name', 'openIssuesCount', 'owner', 'pushedAt', 'size', 'stargazersCount',
            'updatedAt', 'url', 'visibility', 'watchersCount'
        )
        $search = @{
            Subcommand = 'repos'
            JsonFields = $fields -join ','
            Command    = $MyInvocation.MyCommand
            Bound      = $PSBoundParameters
            Flag       = $flags
            Date       = @('Created', 'Updated')
            Query      = $Query
        }
        $arguments = ConvertTo-GitHubSearchArgument @search

        $out = Invoke-GitHubCommand -Activity 'Searching repositories' -Argument $arguments
        return ConvertFrom-GitHubJson -Line $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
