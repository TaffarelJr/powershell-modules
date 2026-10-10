function Submit-GitHubPullRequestReview {
    <#
    .SYNOPSIS
        Reviews a pull request: approves it, requests changes, or
        comments.
    .DESCRIPTION
        The review body travels to gh on standard input, so a multi-line
        body arrives intact. GitHub requires a body for a comment or a
        change request; an approval may go without one.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Decision
        The review's verdict: Approve, RequestChanges, or Comment.
    .PARAMETER Body
        The review's text.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [Parameter(Mandatory)]
        [ValidateSet('Approve', 'RequestChanges', 'Comment')]
        [string]$Decision,

        [string]$Body,

        [string]$Repository
    )

    $flags = @{
        Approve        = '--approve'
        RequestChanges = '--request-changes'
        Comment        = '--comment'
    }

    $arguments = @('pr', 'review')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    $arguments += $flags[$Decision]
    if ($PSBoundParameters.ContainsKey('Body')) {
        $arguments += @('--body-file', '-')
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Body')) {
        $extra['StdIn'] = $Body
    }

    Invoke-GitHubCommand -Activity 'Reviewing the pull request' -Arguments $arguments -Repository $Repository @extra | Out-Null
}
