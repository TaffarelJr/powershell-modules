function Get-GitHubPullRequestStatus {
    <#
    .SYNOPSIS
        Returns the pull requests relevant to the authenticated user in
        a repository: the current branch's, their own, and those awaiting
        their review.
    .PARAMETER ConflictStatus
        Includes each pull request's merge-conflict status.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object with CurrentBranch (one pull request, or $null),
        CreatedBy, and NeedsReview (arrays of pull requests).
    #>
    param(
        [switch]$ConflictStatus,

        [string]$Repository
    )

    $fields = 'additions,assignees,author,autoMergeRequest,baseRefName,body,changedFiles,closedAt,createdAt,deletions,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,isDraft,labels,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,reviewDecision,reviewRequests,state,statusCheckRollup,title,updatedAt,url'
    $arguments = @('pr', 'status', '--json', $fields)
    if ($ConflictStatus) {
        $arguments += '--conflict-status'
    }

    $out = Invoke-GitHubCommand -Activity 'Reading pull request status' -Arguments $arguments -Repository $Repository
    return ConvertFrom-GitHubJson -Lines $out
}
