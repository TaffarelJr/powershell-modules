function New-GitHubPullRequest {
    <#
    .SYNOPSIS
        Opens a pull request.
    .DESCRIPTION
        gh needs either a title and body or one of the -Fill options to
        work without prompting; with neither, it fails rather than asks.
        The body travels to gh on standard input, so a long or multi-line
        body arrives intact and never bloats a failure message.
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
        Labels to add.
    .PARAMETER Assignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER Reviewer
        Users or teams to request a review from, by handle.
    .PARAMETER Milestone
        A milestone to add the pull request to, by name.
    .PARAMETER Project
        Projects to add the pull request to, by title.
    .PARAMETER Template
        A pull request template file to start the body from.
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
        Prints what would be created instead of creating it.
    .PARAMETER Repository
        The repository to open it in, in [HOST/]OWNER/REPO form. Omit it
        to use the current directory's repository.
    .OUTPUTS
        The new pull request's URL.
    #>
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

        [string]$Template,

        [switch]$Fill,

        [switch]$FillFirst,

        [switch]$FillVerbose,

        [switch]$NoMaintainerEdit,

        [switch]$DryRun,

        [string]$Repository
    )

    $arguments = @('pr', 'create')
    if ($Title) {
        $arguments += @('--title', $Title)
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $arguments += @('--body-file', '-')
    }

    if ($Base) {
        $arguments += @('--base', $Base)
    }

    if ($Head) {
        $arguments += @('--head', $Head)
    }

    if ($Draft) {
        $arguments += '--draft'
    }

    foreach ($name in $Label) {
        $arguments += @('--label', $name)
    }

    foreach ($login in $Assignee) {
        $arguments += @('--assignee', $login)
    }

    foreach ($handle in $Reviewer) {
        $arguments += @('--reviewer', $handle)
    }

    if ($Milestone) {
        $arguments += @('--milestone', $Milestone)
    }

    foreach ($title in $Project) {
        $arguments += @('--project', $title)
    }

    if ($Template) {
        $arguments += @('--template', $Template)
    }

    if ($Fill) {
        $arguments += '--fill'
    }

    if ($FillFirst) {
        $arguments += '--fill-first'
    }

    if ($FillVerbose) {
        $arguments += '--fill-verbose'
    }

    if ($NoMaintainerEdit) {
        $arguments += '--no-maintainer-edit'
    }

    if ($DryRun) {
        $arguments += '--dry-run'
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Body')) {
        $extra['StdIn'] = $Body
    }

    $out = Invoke-GitHubCommand -Activity 'Creating the pull request' -Arguments $arguments -Repository $Repository @extra
    return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
}
