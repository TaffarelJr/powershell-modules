function Find-GitHubCommit {
    <#
    .SYNOPSIS
        Searches GitHub for commits.
    .PARAMETER Query
        Search keywords. Omit it to rely on the filters alone.
    .PARAMETER Owner
        Only commits in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only commits in this repository, in OWNER/REPO form.
    .PARAMETER Author
        Only commits by this GitHub user.
    .PARAMETER AuthorName
        Only commits whose author name matches this.
    .PARAMETER AuthorEmail
        Only commits whose author email matches this.
    .PARAMETER AuthorDate
        A date range on when the commit was authored.
    .PARAMETER Committer
        Only commits committed by this GitHub user.
    .PARAMETER CommitterName
        Only commits whose committer name matches this.
    .PARAMETER CommitterEmail
        Only commits whose committer email matches this.
    .PARAMETER CommitterDate
        A date range on when the commit was committed.
    .PARAMETER Hash
        Only the commit with this hash.
    .PARAMETER Parent
        Only commits with this parent hash.
    .PARAMETER Tree
        Only commits with this tree hash.
    .PARAMETER Merge
        Only merge commits.
    .PARAMETER Visibility
        Only commits in repositories with one of these visibilities:
        public, private, or internal.
    .PARAMETER Sort
        Orders by author-date or committer-date. gh's default is
        best-match.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default). Only applies
        with -Sort.
    .PARAMETER Limit
        The most results to fetch. gh's default is 30.
    .OUTPUTS
        One object per commit - Sha, Commit, Author, Committer, Parents,
        Repository, Url - always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [string[]]$Owner,

        [string]$Repository,

        [string]$Author,

        [string]$AuthorName,

        [string]$AuthorEmail,

        [string]$AuthorDate,

        [string]$Committer,

        [string]$CommitterName,

        [string]$CommitterEmail,

        [string]$CommitterDate,

        [string]$Hash,

        [string]$Parent,

        [string]$Tree,

        [switch]$Merge,

        [string[]]$Visibility,

        [ValidateSet('author-date', 'committer-date')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit
    )

    $fields = 'author,commit,committer,id,parents,repository,sha,url'
    $arguments = @('search', 'commits')
    if ($Query) {
        $arguments += $Query
    }

    $arguments += @('--json', $fields)
    foreach ($name in $Owner) {
        $arguments += @('--owner', $name)
    }

    if ($Author) {
        $arguments += @('--author', $Author)
    }

    if ($AuthorName) {
        $arguments += @('--author-name', $AuthorName)
    }

    if ($AuthorEmail) {
        $arguments += @('--author-email', $AuthorEmail)
    }

    if ($AuthorDate) {
        $arguments += @('--author-date', $AuthorDate)
    }

    if ($Committer) {
        $arguments += @('--committer', $Committer)
    }

    if ($CommitterName) {
        $arguments += @('--committer-name', $CommitterName)
    }

    if ($CommitterEmail) {
        $arguments += @('--committer-email', $CommitterEmail)
    }

    if ($CommitterDate) {
        $arguments += @('--committer-date', $CommitterDate)
    }

    if ($Hash) {
        $arguments += @('--hash', $Hash)
    }

    if ($Parent) {
        $arguments += @('--parent', $Parent)
    }

    if ($Tree) {
        $arguments += @('--tree', $Tree)
    }

    if ($Merge) {
        $arguments += '--merge'
    }

    foreach ($value in $Visibility) {
        $arguments += @('--visibility', $value)
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

    $out = Invoke-GitHubCommand -Activity 'Searching commits' -Arguments $arguments -Repository $Repository
    $commits = ConvertFrom-GitHubJson -Lines $out
    return , @($commits)
}
