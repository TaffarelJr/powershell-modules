#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act - no fields asked for
$default = & $module { Get-GitHubPullRequestField }

# Assert
$expected = 'additions,assignees,author,autoMergeRequest,baseRefName,body,changedFiles,closedAt,createdAt,' +
'deletions,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,isDraft,labels,' +
'mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,reviewDecision,reviewRequests,state,' +
'statusCheckRollup,title,updatedAt,url'
Assert-Equal -Expected $expected -Actual $default `
    -Message 'The default is every cheap field, and none that needs a scope or is gone'

#───────────────────────────────────────────────────────────────────────────────
# Act - fields asked for by their property names
$fields = & $module { Get-GitHubPullRequestField -Property 'Title, Files', 'latestReviews' }

# Assert
Assert-Equal -Expected 'title,files,latestReviews,url,number' -Actual $fields `
    -Message 'Asked-for fields are gh''s spelling, with url and number added so a result pipes on'

#───────────────────────────────────────────────────────────────────────────────
# Act - fields that already hold url and number
$fields = & $module { Get-GitHubPullRequestField -Property 'number', 'url', 'title' }

# Assert
Assert-Equal -Expected 'number,url,title' -Actual $fields -Message 'url and number are not added twice'

#───────────────────────────────────────────────────────────────────────────────
# Act - $null and an empty list
$fromNull = & $module { Get-GitHubPullRequestField -Property $null }
$fromEmpty = & $module { Get-GitHubPullRequestField -Property @() }

# Assert
Assert-Equal -Expected $expected -Actual $fromNull -Message '$null asks for the default'
Assert-Equal -Expected $expected -Actual $fromEmpty -Message 'and so does an empty list'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - values that name no field
Assert-Throws -ScriptBlock {
    & $module { Get-GitHubPullRequestField -Property ' , ' }
} -MessageLike "-Property names no field: ' , '.*" `
    -Message 'Values naming no field throw rather than meaning the default'

exit (Complete-TestRun)
