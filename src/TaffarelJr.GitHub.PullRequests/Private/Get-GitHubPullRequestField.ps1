using namespace System.Collections.Generic

function Get-GitHubPullRequestField {
    <#
    .SYNOPSIS
        Returns the fields to ask gh for when it reads pull requests, as
        the one comma-separated string --json takes.
    .DESCRIPTION
        -Property when given, with url and number added when missing, so
        every pull request this module returns can be piped on to another
        of its functions and is found in the repository it came from.
        Otherwise the default: every field that is cheap to fetch and
        needs nothing extra from the token. Left out of that default are
        the fields that bring a whole list per pull request - comments,
        commits, files, reviews, latestReviews, closingIssuesReferences;
        projectItems, which needs the read:project scope; and
        projectCards, which GitHub does not serve, so gh's query for it
        fails.
    .PARAMETER Property
        The fields to ask for, spelled as gh or as a result's property
        spells them (headRefName or HeadRefName), one per value or several
        separated by commas.
    .OUTPUTS
        The fields, comma-separated.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Property
    )

    $default = 'additions,assignees,author,autoMergeRequest,baseRefName,body,changedFiles,closedAt,createdAt,' +
    'deletions,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,isDraft,labels,' +
    'mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,reviewDecision,reviewRequests,state,' +
    'statusCheckRollup,title,updatedAt,url'

    $list = ConvertTo-GitHubJsonFieldList -Property $Property -Default $default
    $fields = [List[string]]::new([string[]]$list.Split(','))
    foreach ($required in 'url', 'number') {
        if ($fields -cnotcontains $required) {
            $fields.Add($required)
        }
    }

    return $fields -join ','
}
