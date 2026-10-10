function Add-GitHubPullRequestComment {
    <#
    .SYNOPSIS
        Comments on a pull request, or edits the authenticated user's
        last comment there.
    .DESCRIPTION
        The comment travels to gh on standard input, so a long or
        multi-line comment arrives intact.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Body
        The comment's text, as Markdown.
    .PARAMETER EditLast
        Replaces the authenticated user's most recent comment instead of
        adding a new one.
    .PARAMETER CreateIfNone
        With -EditLast, adds a new comment when there is none to edit.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [Parameter(Mandatory)]
        [string]$Body,

        [switch]$EditLast,

        [switch]$CreateIfNone,

        [string]$Repository
    )

    $arguments = @('pr', 'comment')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    $arguments += @('--body-file', '-')
    if ($EditLast) {
        $arguments += '--edit-last'
    }

    if ($CreateIfNone) {
        $arguments += '--create-if-none'
    }

    Invoke-GitHubCommand -Activity 'Commenting on the pull request' -Arguments $arguments -Repository $Repository -StdIn $Body | Out-Null
}
