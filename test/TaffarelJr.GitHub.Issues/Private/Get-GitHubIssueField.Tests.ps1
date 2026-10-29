#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act - the default fields
$default = & $module { Get-GitHubIssueField }

# Assert
$expected = @(
    'assignees', 'author', 'blockedBy', 'blocking', 'body', 'closed', 'closedAt', 'closedByPullRequestsReferences'
    'createdAt', 'id', 'isPinned', 'issueType', 'labels', 'milestone', 'number', 'parent', 'reactionGroups'
    'state', 'stateReason', 'subIssues', 'subIssuesSummary', 'title', 'updatedAt', 'url'
) -join ','
Assert-Equal -Expected $expected -Actual $default `
    -Message 'The default is the fields that are cheap and need no extra scope - no comments, projectItems or projectCards'

#───────────────────────────────────────────────────────────────────────────────
# Act - fields asked for by name, without number or url
$asked = & $module { Get-GitHubIssueField -Property 'title', 'comments' }

# Assert
Assert-Equal -Expected 'title,comments,number,url' -Actual $asked `
    -Message 'Named fields replace the default, in the order given, and number and url are added so the issue can be acted on'

#───────────────────────────────────────────────────────────────────────────────
# Act - fields that already hold both, in the order given
$both = & $module { Get-GitHubIssueField -Property 'url', 'title', 'number' }

# Assert
Assert-Equal -Expected 'url,title,number' -Actual $both -Message 'neither is added twice'

#───────────────────────────────────────────────────────────────────────────────
# Act - names with spaces, empty entries, and PascalCase, given as one value
$one = & $module { Get-GitHubIssueField -Property ' Number , title,', 'StateReason' }

# Assert
Assert-Equal -Expected 'number,title,stateReason,url' -Actual $one `
    -Message 'Each name is trimmed and lower-cased at its first letter, and empty ones are dropped'

#───────────────────────────────────────────────────────────────────────────────
# Act - given as nothing
$none = & $module { Get-GitHubIssueField -Property @() }

# Assert
Assert-Equal -Expected $default -Actual $none -Message 'An empty list asks for the default'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - given as names that are all empty
Assert-Throws -ScriptBlock {
    & $module { Get-GitHubIssueField -Property '' }
} -MessageLike "*-Property names no field: ''.*" `
    -Message 'A -Property naming no field is refused, not taken for the default'

exit (Complete-TestRun)
