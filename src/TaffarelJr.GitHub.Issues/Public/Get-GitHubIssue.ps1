function Get-GitHubIssue {
    <#
    .SYNOPSIS
        Returns one issue, or lists a repository's issues.
    .DESCRIPTION
        Without -List, one issue is described: the one named. With
        -List, the repository's open issues are returned, narrowed by
        the filters.

        Every field comes back that is cheap to fetch and needs nothing
        extra from the token. Name the fields with -Property to get fewer,
        or ones left out: comments, and projectItems, which needs a token
        with the read:project scope. The default needs gh 2.94 or later,
        for issueType, parent, subIssues and the blocked-by fields; with
        an older gh, name the fields it has.
    .PARAMETER Issue
        The issue to describe: its number or URL, or an issue object, such
        as one a listing returned. A pull request's URL or object is
        refused.
    .PARAMETER List
        Lists issues instead of describing one.
    .PARAMETER State
        Lists issues in this state: open, closed, or all, in any casing.
        gh's default is open.
    .PARAMETER Author
        Lists only issues by this author. '@me' is the authenticated
        user. Given with -App, it throws, as gh refuses the pair.
    .PARAMETER App
        Lists only issues opened by this GitHub App.
    .PARAMETER Assignee
        Lists only issues assigned to this user.
    .PARAMETER Mention
        Lists only issues mentioning this user. -Mentions works too.
    .PARAMETER Label
        Lists only issues carrying every one of these labels.
    .PARAMETER Milestone
        Lists only issues in this milestone, by number or title.
    .PARAMETER Type
        Lists only issues of this issue type. Needs gh 2.94 or later.
    .PARAMETER Search
        Lists only issues matching this GitHub search query.
    .PARAMETER Limit
        The most issues to list, at least 1. gh's default is 30.
    .PARAMETER Property
        The fields to return, spelled as gh spells them (stateReason
        style) or as the returned properties are (StateReason), such as
        number, title, comments. number and url always come back too, so
        an issue piped on is found in the repository it came from. Omit it
        for the default set, which needs gh 2.94 or later.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. An issue given by URL or
        object is in the repository it names; one in a different repository
        than this throws.
    .INPUTS
        System.Object
        The issue to describe, bound to -Issue: its number or URL, or an
        issue object, such as one a listing returned.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per issue with the fields asked for - by default Number,
        Url, Title, State, StateReason, IsPinned, IssueType, Author,
        Assignees, Labels, Milestone, Body, Parent, SubIssues, BlockedBy,
        Blocking, the timestamps, and the rest of the default fields. A
        single object without -List; one per issue with it.
    .EXAMPLE
        Get-GitHubIssue -Issue 12 -Repository OWNER/REPO

        Returns issue 12 of OWNER/REPO with every field gh offers by default.
    .EXAMPLE
        Get-GitHubIssue -List -State all -Limit 100 -Repository OWNER/REPO

        Lists up to 100 issues of OWNER/REPO, open and closed.
    .EXAMPLE
        Get-GitHubIssue -List -Property title, labels -Repository OWNER/REPO

        Lists OWNER/REPO's open issues with only their Title and Labels, and
        the Number and Url that always come back.
    .EXAMPLE
        Get-GitHubIssue -List -Label stale -Repository OWNER/REPO |
            Close-GitHubIssue -Reason 'not planned'

        Lists OWNER/REPO's open issues labeled stale and closes each of them
        in OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Get-GitHubIssueStatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'View', ValueFromPipeline)]
        [object]$Issue,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('open', 'closed', 'all')]
        [string]$State,

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
        [Alias('Mentions')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Mention was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Mention off.'
        )]
        [string]$Mention,

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
            ErrorMessage = '-Milestone was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Milestone off.'
        )]
        [string]$Milestone,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Type was given but is blank, so it would filter nothing. Give a value, or leave -Type off.'
        )]
        [string]$Type,

        [Parameter(ParameterSetName = 'List')]
        [ValidatePattern(
            '\S',
            ErrorMessage = '-Search was given but is blank, so it would filter nothing.' +
            ' Give a value, or leave -Search off.'
        )]
        [string]$Search,

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
            $fields = Get-GitHubIssueField -Property $Property
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
                $reference = Resolve-GitHubItemReference -Item $Issue -Kind Issue -Repository $repositoryReference
                $invocation = @{
                    Activity   = "Reading issue $reference"
                    Arguments  = @('issue', 'view', $reference, '--json', $fields)
                    Repository = $repositoryReference
                }
                $out = Invoke-GitHubCommand @invocation
                return ConvertFrom-GitHubJson -Lines $out
            }

            $arguments = @('issue', 'list', '--json', $fields)
            if ($State) {
                $arguments += @('--state', $State.ToLowerInvariant())
            }

            $filters = [ordered]@{
                '--author'    = $Author
                '--app'       = $App
                '--assignee'  = $Assignee
                '--mention'   = $Mention
                '--milestone' = $Milestone
                '--type'      = $Type
                '--search'    = $Search
            }
            foreach ($flag in $filters.Keys) {
                if ($filters[$flag]) {
                    $arguments += "$flag=$($filters[$flag])"
                }
            }

            $arguments += ConvertTo-GitHubIssueListArgument -Name 'Label' -Flag '--label' -Value $Label

            if ($PSBoundParameters.ContainsKey('Limit')) {
                $arguments += @('--limit', $Limit)
            }

            $invocation = @{
                Activity   = 'Listing issues'
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            $out = Invoke-GitHubCommand @invocation
            return ConvertFrom-GitHubJson -Lines $out
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
