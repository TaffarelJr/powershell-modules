function New-GitHubIssue {
    <#
    .SYNOPSIS
        Opens an issue.
    .DESCRIPTION
        The body travels to gh on standard input, so multi-line Markdown
        arrives intact.
    .PARAMETER Title
        The issue's title.
    .PARAMETER Body
        The issue's body, as Markdown.
    .PARAMETER Assignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER Label
        Labels to add.
    .PARAMETER Milestone
        A milestone to add the issue to, by name.
    .PARAMETER Project
        Projects to add the issue to, by title.
    .PARAMETER Template
        A template name to start the body from.
    .PARAMETER Type
        The issue type, by name.
    .PARAMETER Parent
        Makes the new issue a sub-issue of this parent, by number or URL.
    .PARAMETER BlockedBy
        Issue numbers or URLs this issue is blocked by.
    .PARAMETER Blocking
        Issue numbers or URLs this issue blocks.
    .PARAMETER Repository
        The repository to open it in, in [HOST/]OWNER/REPO form. Omit it
        to use the current directory's repository.
    .OUTPUTS
        The new issue's URL.
    #>
    param(
        [string]$Title,

        [string]$Body,

        [string[]]$Assignee,

        [string[]]$Label,

        [string]$Milestone,

        [string[]]$Project,

        [string]$Template,

        [string]$Type,

        [string]$Parent,

        [string[]]$BlockedBy,

        [string[]]$Blocking,

        [string]$Repository
    )

    $arguments = @('issue', 'create')
    if ($Title) {
        $arguments += @('--title', $Title)
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $arguments += @('--body-file', '-')
    }

    foreach ($login in $Assignee) {
        $arguments += @('--assignee', $login)
    }

    foreach ($name in $Label) {
        $arguments += @('--label', $name)
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

    if ($Type) {
        $arguments += @('--type', $Type)
    }

    if ($Parent) {
        $arguments += @('--parent', $Parent)
    }

    foreach ($number in $BlockedBy) {
        $arguments += @('--blocked-by', $number)
    }

    foreach ($number in $Blocking) {
        $arguments += @('--blocking', $number)
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Body')) {
        $extra['StdIn'] = $Body
    }

    $out = Invoke-GitHubCommand -Activity 'Creating the issue' -Arguments $arguments -Repository $Repository @extra
    return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
}
