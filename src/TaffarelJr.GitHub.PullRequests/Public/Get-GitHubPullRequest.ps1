function Get-GitHubPullRequest {
    <#
    .SYNOPSIS
        Returns one pull request, or lists a repository's pull requests.
    .DESCRIPTION
        Without -List, one pull request is described: the one named, or
        the current branch's. With -List, the repository's open pull
        requests are returned, narrowed by the filters. A filter given
        blank throws rather than widening the listing.
    .PARAMETER PullRequest
        The pull request to describe: its number, URL, or head branch, or
        a pull request object such as one a listing returned. Leave it out
        to use the current branch's pull request, which works only without
        -Repository: gh needs the pull request named along with it. Given
        as $null, it throws.
    .PARAMETER List
        Lists pull requests instead of describing one.
    .PARAMETER State
        Lists pull requests in this state: open, closed, merged, or all,
        in any casing. gh's default is open.
    .PARAMETER Base
        Lists only pull requests into this base branch.
    .PARAMETER Head
        Lists only pull requests from this head branch, by its name alone:
        gh does not take the OWNER:BRANCH form here.
    .PARAMETER Author
        Lists only pull requests by this author. '@me' is the
        authenticated user. Given with -App, it throws, as gh refuses the
        pair.
    .PARAMETER App
        Lists only pull requests opened by this GitHub App, such as
        dependabot.
    .PARAMETER Assignee
        Lists only pull requests assigned to this user.
    .PARAMETER Label
        Lists only pull requests carrying every one of these labels.
    .PARAMETER Search
        Lists only pull requests matching this GitHub search query.
    .PARAMETER Draft
        Lists only drafts, or with -Draft:$false only non-drafts.
    .PARAMETER Limit
        The most pull requests to list, at least 1. gh's default is 30.
    .PARAMETER Property
        The fields to ask gh for instead of the default set, such as
        'files' or 'latestReviews', as gh spells them or as a result's
        property does. Url and Number are always added, so a result can
        be piped on to the other functions of this module.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A pull request given by URL
        or object is in the repository it names; one in a different
        repository than this throws.
    .INPUTS
        System.Object
        A pull request: its number, URL, or head branch, or a pull request
        object such as Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per pull request with Number, Title, State, IsDraft,
        Url, Author, BaseRefName, HeadRefName, HeadRefOid, Labels,
        Assignees, ReviewDecision, Mergeable, MergeStateStatus,
        StatusCheckRollup, Body, and the timestamps - ClosedAt and
        MergedAt are $null while it is open - or the -Property fields.
        A single object without -List; one per pull request with it.
    .EXAMPLE
        Get-GitHubPullRequest -PullRequest 42 -Repository 'OWNER/REPO'

        Returns pull request 42 of OWNER/REPO.
    .EXAMPLE
        Get-GitHubPullRequest -List -State merged -Base main -Limit 10 `
            -Repository 'OWNER/REPO'

        Lists up to 10 merged pull requests into main.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequestStatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View', ValueFromPipeline)]
        [object]$PullRequest,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('open', 'closed', 'merged', 'all')]
        [string]$State,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Base was given but is blank, so it would filter nothing. Give a value, or leave -Base off.'
        )]
        [string]$Base,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Head was given but is blank, so it would filter nothing. Give a value, or leave -Head off.'
        )]
        [string]$Head,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Author was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Author off.'
        )]
        [string]$Author,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-App was given but is blank, so it would filter nothing. Give a value, or leave -App off.'
        )]
        [string]$App,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Assignee was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Assignee off.'
        )]
        [string]$Assignee,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Label was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Label off.'
        )]
        [string[]]$Label,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Search was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Search off.'
        )]
        [string]$Search,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Draft,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [string[]]$Property,

        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if ($Author -and $App) {
                throw '-Author and -App cannot be used together: gh lists by one author or the other. Give only one.'
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $fields = Get-GitHubPullRequestField -Property $Property
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            if (-not $List) {
                $resolve = @{
                    BoundParameters = $PSBoundParameters
                    Repository      = $repositoryReference
                }
                $target = Resolve-GitHubPullRequestTarget @resolve
                $command = @{
                    Activity   = "Reading $($target.Name)"
                    Arguments  = @('pr', 'view') + $target.Arguments + @('--json', $fields)
                    Repository = $repositoryReference
                }
                $out = Invoke-GitHubCommand @command
                return ConvertFrom-GitHubJson -Lines $out
            }

            $arguments = @('pr', 'list', '--json', $fields)
            if ($State) {
                $arguments += @('--state', $State.ToLowerInvariant())
            }

            $filters = [ordered]@{
                '--base'     = $Base
                '--head'     = $Head
                '--author'   = $Author
                '--app'      = $App
                '--assignee' = $Assignee
            }
            foreach ($flag in $filters.Keys) {
                if ($filters[$flag]) {
                    $arguments += "$flag=$($filters[$flag])"
                }
            }

            $arguments += ConvertTo-GitHubPullRequestListArgument -Name 'Label' -Flag '--label' -Value $Label
            if ($Search) {
                $arguments += "--search=$Search"
            }

            if ($PSBoundParameters.ContainsKey('Draft')) {
                $arguments += "--draft=$($Draft.ToString().ToLowerInvariant())"
            }

            if ($PSBoundParameters.ContainsKey('Limit')) {
                $arguments += @('--limit', $Limit)
            }

            $command = @{
                Activity   = 'Listing pull requests'
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            $out = Invoke-GitHubCommand @command
            return ConvertFrom-GitHubJson -Lines $out
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
