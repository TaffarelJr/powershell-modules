function New-GitHubPullRequest {
    <#
    .SYNOPSIS
        Opens a pull request.
    .DESCRIPTION
        gh needs either a title and body or one of the -Fill options to
        work without prompting; with neither, it fails rather than asks.
        Only one -Fill option can be given; a -Title or -Body given along
        with it is used instead of the one from the commits. The body
        reaches gh through a temporary file, so it arrives exactly as
        given and never bloats a failure message. A blank title, base,
        head, or milestone throws, and so does a blank name in any list.

        There is no -Template: gh applies a template only along with its
        own prompts or editor, never when it is given the details to go on.

        With -DryRun, the details gh prints come back as text lines instead
        of a URL. gh may still push the branch on a dry run.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Title
        The pull request's title.
    .PARAMETER Body
        The pull request's body, as Markdown.
    .PARAMETER Base
        The branch to merge into. Omit it for the repository's default
        branch.
    .PARAMETER Head
        The branch with the changes, as BRANCH or USER:BRANCH. Omit it
        for the current branch.
    .PARAMETER Draft
        Opens the pull request as a draft.
    .PARAMETER Label
        Labels to add, by name.
    .PARAMETER Assignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER Reviewer
        Users or teams to request a review from, by handle.
    .PARAMETER Milestone
        A milestone to add the pull request to, by name.
    .PARAMETER Project
        Projects to add the pull request to, by title.
    .PARAMETER Fill
        Takes the title and body from the commits instead.
    .PARAMETER FillFirst
        Takes the title and body from the first commit instead.
    .PARAMETER FillVerbose
        Takes the title and body from every commit's message and body.
    .PARAMETER NoMaintainerEdit
        Stops maintainers of the base repository from pushing to the head
        branch.
    .PARAMETER DryRun
        Returns what would be created instead of creating it.
    .PARAMETER Repository
        The repository to open it in, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current directory's
        repository; given as $null, it throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The new pull request's URL; with -DryRun, the lines gh prints.
    .EXAMPLE
        New-GitHubPullRequest -Title 'Add retry' -Body 'Retries twice.' `
            -Base main -Head feature/retry -Repository 'OWNER/REPO'

        Opens a pull request from feature/retry into main in OWNER/REPO
        and returns its URL.
    .EXAMPLE
        New-GitHubPullRequest -Fill -Draft -Repository 'OWNER/REPO'

        Opens a draft pull request for the current branch, with the title
        and body taken from its commits.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Details', PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [string]$Title,

        [string]$Body,

        [string]$Base,

        [string]$Head,

        [switch]$Draft,

        [string[]]$Label,

        [string[]]$Assignee,

        [string[]]$Reviewer,

        [string]$Milestone,

        [string[]]$Project,

        [Parameter(ParameterSetName = 'Fill')]
        [switch]$Fill,

        [Parameter(ParameterSetName = 'FillFirst')]
        [switch]$FillFirst,

        [Parameter(ParameterSetName = 'FillVerbose')]
        [switch]$FillVerbose,

        [switch]$NoMaintainerEdit,

        [switch]$DryRun,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $blanks = [ordered]@{
            Title     = 'a title'
            Base      = 'the base branch'
            Head      = 'the head branch'
            Milestone = 'a milestone name'
        }
        foreach ($name in $blanks.Keys) {
            if ($PSBoundParameters.ContainsKey($name) -and [string]::IsNullOrWhiteSpace($PSBoundParameters[$name])) {
                throw "-$name is blank: give $($blanks[$name]), or leave it out."
            }
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $before = @('pr', 'create')
        if ($Title) {
            $before += "--title=$Title"
        }

        $after = @()
        if ($Base) {
            $after += "--base=$Base"
        }

        if ($Head) {
            $after += "--head=$Head"
        }

        if ($Draft) {
            $after += '--draft'
        }

        $lists = [ordered]@{
            Label    = '--label'
            Assignee = '--assignee'
            Reviewer = '--reviewer'
        }
        foreach ($name in $lists.Keys) {
            $convert = @{
                Name  = $name
                Flag  = $lists[$name]
                Value = $PSBoundParameters[$name]
            }
            $after += ConvertTo-GitHubPullRequestListArgument @convert
        }

        if ($Milestone) {
            $after += "--milestone=$Milestone"
        }

        $after += ConvertTo-GitHubPullRequestListArgument -Name 'Project' -Flag '--project' -Value $Project
        $switches = [ordered]@{
            '--fill'               = $Fill
            '--fill-first'         = $FillFirst
            '--fill-verbose'       = $FillVerbose
            '--no-maintainer-edit' = $NoMaintainerEdit
            '--dry-run'            = $DryRun
        }
        foreach ($flag in $switches.Keys) {
            if ($switches[$flag]) {
                $after += $flag
            }
        }

        $kind = 'pull request'
        if ($Draft) {
            $kind = 'draft pull request'
        }

        $action = if ($DryRun) { "Dry-run creating a $kind" } else { "Create $kind" }
        if ($Title) {
            $shownTitle = Hide-UrlCredential -Text $Title
            $action += " '$shownTitle'"
        }

        if ($Head) {
            $shownHead = Hide-UrlCredential -Text $Head
            $action += " from $shownHead"
        }

        if ($Base) {
            $shownBase = Hide-UrlCredential -Text $Base
            $action += " into $shownBase"
        }

        $sources = [ordered]@{
            'the commits'      = $Fill
            'the first commit' = $FillFirst
            'every commit'     = $FillVerbose
        }
        foreach ($source in $sources.Keys) {
            if ($sources[$source]) {
                $action += ", filled in from $source"
            }
        }

        if ($DryRun) {
            $action += ', which may push the head branch'
        }

        $subject = "the current directory's repository"
        if ($repositoryReference) {
            $subject = Format-GitHubRepositoryName -Repository $repositoryReference
        }

        if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
            return
        }

        $command = @{
            Activity   = 'Creating the pull request'
            Arguments  = $before + $after
            Repository = $repositoryReference
        }
        if ($PSBoundParameters.ContainsKey('Body')) {
            $create = {
                param($File)

                $command.Arguments = $before + @('--body-file', $File) + $after
                Invoke-GitHubCommand @command
            }
            $out = Use-GitHubTextFile -Text $Body -ScriptBlock $create
        }
        else {
            $out = Invoke-GitHubCommand @command
        }

        if ($DryRun) {
            return $out
        }

        return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
