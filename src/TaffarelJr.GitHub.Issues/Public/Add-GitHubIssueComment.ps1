function Add-GitHubIssueComment {
    <#
    .SYNOPSIS
        Comments on an issue, or edits the authenticated user's last
        comment there.
    .DESCRIPTION
        The comment travels to gh on standard input, so a long or
        multi-line comment arrives intact.
    .PARAMETER Issue
        The issue to comment on: its number or URL.
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
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [Parameter(Mandatory)]
        [string]$Body,

        [switch]$EditLast,

        [switch]$CreateIfNone,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'comment', $Issue, '--body-file', '-')
        if ($EditLast) {
            $arguments += '--edit-last'
        }

        if ($CreateIfNone) {
            $arguments += '--create-if-none'
        }

        Invoke-GitHubCommand -Activity "Commenting on issue $Issue" -Arguments $arguments -Repository $Repository -StdIn $Body | Out-Null
    }
}
