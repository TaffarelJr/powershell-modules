function Get-GitHubIssueStatus {
    <#
    .SYNOPSIS
        Returns the issues relevant to the authenticated user in a
        repository: issues assigned to them, created by them, and
        mentioning them.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object with Assigned, CreatedBy, and Mentioned - each an
        array of issues.
    #>
    param(
        [string]$Repository
    )

    $fields = 'assignees,author,blockedBy,blocking,body,closed,closedAt,closedByPullRequestsReferences,comments,createdAt,id,isPinned,issueType,labels,milestone,number,parent,projectCards,projectItems,reactionGroups,state,stateReason,subIssues,subIssuesSummary,title,updatedAt,url'
    $arguments = @('issue', 'status', '--json', $fields)
    $out = Invoke-GitHubCommand -Activity 'Reading issue status' -Arguments $arguments -Repository $Repository
    return ConvertFrom-GitHubJson -Lines $out
}
