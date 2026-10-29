using namespace System.Collections.Generic

function Get-GitHubIssueField {
    <#
    .SYNOPSIS
        Returns the fields to ask gh for when it reads issues, as the one
        comma-separated string --json takes.
    .DESCRIPTION
        -Property when given, otherwise every field that is cheap to fetch
        and needs nothing extra from the token. Left out of that default
        are comments, which brings the whole thread of every issue;
        projectItems, which needs the read:project scope; and projectCards,
        which GitHub does not serve, so gh's query for it fails.

        number and url are always asked for, whatever -Property says: an
        issue piped on to another function is found by its url, in the
        repository it came from, and without one only its number would be
        left, which gh looks up in the current directory's repository.
    .PARAMETER Property
        The fields to ask for, as ConvertTo-GitHubJsonFieldList reads them:
        names or comma-separated lists of names, as gh spells them or in
        PascalCase.
    .OUTPUTS
        The fields, comma-separated.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string[]]$Property
    )

    $default = @(
        'assignees', 'author', 'blockedBy', 'blocking', 'body', 'closed', 'closedAt'
        'closedByPullRequestsReferences', 'createdAt', 'id', 'isPinned', 'issueType', 'labels'
        'milestone', 'number', 'parent', 'reactionGroups', 'state', 'stateReason', 'subIssues'
        'subIssuesSummary', 'title', 'updatedAt', 'url'
    ) -join ','
    $list = ConvertTo-GitHubJsonFieldList -Property $Property -Default $default
    $fields = [List[string]]::new([string[]]$list.Split(','))
    foreach ($required in 'number', 'url') {
        if (-not $fields.Contains($required)) {
            $fields.Add($required)
        }
    }

    return $fields -join ','
}
