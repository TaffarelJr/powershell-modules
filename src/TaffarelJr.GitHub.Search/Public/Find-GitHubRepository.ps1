function Find-GitHubRepository {
    <#
    .SYNOPSIS
        Searches GitHub for repositories.
    .PARAMETER Query
        Search keywords. Omit it to rely on the filters alone.
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
        Only archived ($true) or only non-archived ($false) repositories.
    .PARAMETER IncludeForks
        Whether forks are included: false (gh's default), true, or only
        forks.
    .PARAMETER Stars
        A star-count range, such as '>100' or '10..50'.
    .PARAMETER Forks
        A fork-count range.
    .PARAMETER Size
        A size range in kilobytes.
    .PARAMETER GoodFirstIssues
        A range on the number of issues labeled 'good first issue'.
    .PARAMETER HelpWantedIssues
        A range on the number of issues labeled 'help wanted'.
    .PARAMETER NumberTopics
        A range on the number of topics.
    .PARAMETER Created
        A date range on when the repository was created.
    .PARAMETER Updated
        A date range on when the repository was last updated.
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
        The most results to fetch. gh's default is 30.
    .OUTPUTS
        One object per repository - Name, FullName, Owner, Description,
        Url, Language, Visibility, IsPrivate, IsArchived, IsFork,
        StargazersCount, ForksCount, License, and the timestamps -
        always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [string[]]$Owner,

        [string]$Language,

        [string[]]$Topic,

        [string[]]$License,

        [string[]]$Visibility,

        [bool]$Archived,

        [ValidateSet('false', 'true', 'only')]
        [string]$IncludeForks,

        [string]$Stars,

        [string]$Forks,

        [string]$Size,

        [string]$GoodFirstIssues,

        [string]$HelpWantedIssues,

        [string]$NumberTopics,

        [string]$Created,

        [string]$Updated,

        [ValidateSet('name', 'description', 'readme')]
        [string[]]$Match,

        [ValidateSet('forks', 'help-wanted-issues', 'stars', 'updated')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit
    )

    $fields = 'createdAt,defaultBranch,description,forksCount,fullName,hasDownloads,hasIssues,hasPages,hasProjects,hasWiki,homepage,id,isArchived,isDisabled,isFork,isPrivate,language,license,name,openIssuesCount,owner,pushedAt,size,stargazersCount,updatedAt,url,visibility,watchersCount'

    $arguments = @('search', 'repos')
    if ($Query) {
        $arguments += $Query
    }

    $arguments += @('--json', $fields)
    foreach ($name in $Owner) {
        $arguments += @('--owner', $name)
    }

    if ($Language) {
        $arguments += @('--language', $Language)
    }

    foreach ($name in $Topic) {
        $arguments += @('--topic', $name)
    }

    foreach ($name in $License) {
        $arguments += @('--license', $name)
    }

    foreach ($value in $Visibility) {
        $arguments += @('--visibility', $value)
    }

    if ($PSBoundParameters.ContainsKey('Archived')) {
        $arguments += @('--archived', $Archived.ToString().ToLowerInvariant())
    }

    if ($IncludeForks) {
        $arguments += @('--include-forks', $IncludeForks)
    }

    if ($Stars) {
        $arguments += @('--stars', $Stars)
    }

    if ($Forks) {
        $arguments += @('--forks', $Forks)
    }

    if ($Size) {
        $arguments += @('--size', $Size)
    }

    if ($GoodFirstIssues) {
        $arguments += @('--good-first-issues', $GoodFirstIssues)
    }

    if ($HelpWantedIssues) {
        $arguments += @('--help-wanted-issues', $HelpWantedIssues)
    }

    if ($NumberTopics) {
        $arguments += @('--number-topics', $NumberTopics)
    }

    if ($Created) {
        $arguments += @('--created', $Created)
    }

    if ($Updated) {
        $arguments += @('--updated', $Updated)
    }

    foreach ($field in $Match) {
        $arguments += @('--match', $field)
    }

    if ($Sort) {
        $arguments += @('--sort', $Sort)
    }

    if ($Order) {
        $arguments += @('--order', $Order)
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Searching repositories' -Arguments $arguments
    $repositories = ConvertFrom-GitHubJson -Lines $out
    return , @($repositories)
}
