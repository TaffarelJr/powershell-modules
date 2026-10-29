#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Assert-Throws and Get-WhatIfOutput, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case. Where gh is given a temporary file, the one part that
# differs per run is a wildcard between two escaped halves.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$issue = "$url/issues/7"
$shownIssue = "$shown/issues/7"
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
$notRepository = 'is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
$notIssue = 'is not an issue: give its number or URL, or an issue object.'
$wrongKind = 'is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests for it.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every -WhatIf line that names an issue, a repository, or a title it was given
$fake = New-FakeGitHubCli
$previews = @(
    @{
        Block    = { Add-GitHubIssueComment -Issue $issue -Body 'x' -WhatIf }
        Expected = 'What if: Performing the operation "Add comment" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Add-GitHubIssueComment names an issue given by URL without its credential'
    }
    @{
        Block    = { Close-GitHubIssue -Issue $issue -WhatIf }
        Expected = 'What if: Performing the operation "Close issue" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Close-GitHubIssue names it without its credential'
    }
    @{
        Block    = { Open-GitHubIssue -Issue $issue -WhatIf }
        Expected = 'What if: Performing the operation "Reopen issue" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Open-GitHubIssue names it without its credential'
    }
    @{
        Block    = { Lock-GitHubIssue -Issue $issue -WhatIf }
        Expected = 'What if: Performing the operation "Lock issue" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Lock-GitHubIssue names it without its credential'
    }
    @{
        Block    = { Unlock-GitHubIssue -Issue $issue -WhatIf }
        Expected = 'What if: Performing the operation "Unlock issue" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Unlock-GitHubIssue names it without its credential'
    }
    @{
        Block    = { Remove-GitHubIssue -Issue 7 -Repository $url -WhatIf }
        Expected = 'What if: Performing the operation "Delete issue" on target "ghe.example.com/o/r issue #7".'
        Name     = 'Remove-GitHubIssue names an issue number in a repository given by URL without the credential'
    }
    @{
        Block    = { Set-GitHubIssue -Issue $issue -Title 't' -Pinned -WhatIf }
        Expected = @(
            'What if: Performing the operation "Edit issue" on target "ghe.example.com/o/r issue #7".'
            'What if: Performing the operation "Pin issue" on target "ghe.example.com/o/r issue #7".'
        )
        Name     = 'Set-GitHubIssue names it without its credential, for the edit and for the pin'
    }
    @{
        Block    = {
            Move-GitHubIssue -Issue $issue -DestinationRepository 'https://user:SENTINEL@ghe.example.com/o/x.git' `
                -WhatIf
        }
        Expected = 'What if: Performing the operation "Transfer issue to ghe.example.com/o/x"' +
        ' on target "ghe.example.com/o/r issue #7".'
        Name     = 'Move-GitHubIssue names the issue and the destination without a credential'
    }
    @{
        Block    = { New-GitHubIssue -Title "See $url" -Body '' -Repository $url -WhatIf }
        Expected = "What if: Performing the operation `"Create issue 'See $shown'`" on target `"ghe.example.com/o/r`"."
        Name     = 'New-GitHubIssue names the repository and the title without a credential'
    }
)

try {
    foreach ($case in $previews) {
        # Act
        $run = Get-WhatIfOutput -ScriptBlock $case.Block

        # Assert
        Assert-Equal -Expected @($case.Expected) -Actual $run.Messages -Message $case.Name
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$messages = @(
    @{
        Block    = { Move-GitHubIssue -Issue 7 -DestinationRepository 'HTTPS://user:SENTINEL@ghe.example.com/o/x' }
        Expected = "'HTTPS://***@ghe.example.com/o/x' $notRepository"
        Name     = 'Move-GitHubIssue shows a destination gh would not read without its credential'
    }
    @{
        Block    = { Move-GitHubIssue -Issue 7 -DestinationRepository "$url x" }
        Expected = "'$shown x' $notRepository"
        Name     = 'and a destination that holds a space'
    }
    @{
        Block    = { Get-GitHubIssue -List -Repository "$url x" }
        Expected = "'$shown x' $notRepository"
        Name     = 'Get-GitHubIssue shows a -Repository that is no repository without its credential'
    }
    @{
        Block    = { Get-GitHubIssueStatus -Repository "$url x" }
        Expected = "'$shown x' $notRepository"
        Name     = 'Get-GitHubIssueStatus shows it without its credential'
    }
    @{
        Block    = { New-GitHubIssue -Title 't' -Body '' -Repository "$url x" }
        Expected = "'$shown x' $notRepository"
        Name     = 'New-GitHubIssue shows it without its credential'
    }
    @{
        Block    = { Close-GitHubIssue -Issue "$url/pull/7" }
        Expected = "'$shown/pull/7' $wrongKind"
        Name     = 'Close-GitHubIssue shows a pull request URL without its credential'
    }
    @{
        Block    = { Get-GitHubIssue -Issue "$url/issues/x" }
        Expected = "'$shown/issues/x' is not an issue: a URL must end in /OWNER/REPO/issues/NUMBER."
        Name     = 'Get-GitHubIssue shows a URL that names no issue without its credential'
    }
    @{
        Block    = { Remove-GitHubIssue -Issue $issue -Repository 'o/other' }
        Expected = "'$shownIssue' is in ghe.example.com/o/r, but -Repository names o/other: give one or the other."
        Name     = 'Remove-GitHubIssue shows an issue in another repository than -Repository without its credential'
    }
    @{
        Block    = { Open-GitHubIssue -Issue 'u:SENTINEL@h o' }
        Expected = "'***@h o' $notIssue"
        Name     = 'Open-GitHubIssue shows text that is no issue without its credential'
    }
    @{
        Block    = { Lock-GitHubIssue -Issue ([PSCustomObject]@{ Number = 'u:SENTINEL@h' }) }
        Expected = "'***@h' is not an issue number: an object's Number must be a whole number of 1 to 10 digits."
        Name     = 'Lock-GitHubIssue shows an object''s Number that is no number without its credential'
    }
    @{
        Block    = { Close-GitHubIssue -Issue 7 -DuplicateOf "$url/pull/7" }
        Expected = "'$shown/pull/7' $wrongKind"
        Name     = 'Close-GitHubIssue shows a -DuplicateOf that is no issue without its credential'
    }
    @{
        Block    = { New-GitHubIssue -Title 't' -Body '' -Parent 'u:SENTINEL@h o' }
        Expected = "'***@h o' $notIssue"
        Name     = 'New-GitHubIssue shows a -Parent that is no issue without its credential'
    }
    @{
        Block    = { Set-GitHubIssue -Issue 7 -AddBlocking 'u:SENTINEL@h o' }
        Expected = "'***@h o' $notIssue"
        Name     = 'Set-GitHubIssue shows an -AddBlocking that is no issue without its credential'
    }
)

# Act / Assert
foreach ($case in $messages) {
    Assert-Throws -ScriptBlock $case.Block -MessageLike (& $escape $case.Expected) -Message $case.Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL on stdout and stderr
$fake = New-FakeGitHubCli -Output @("moved $url") -ErrorOutput @("Get `"$url`": HTTP 404") -ExitCode 1
$printed = "`nmoved $shown`nGet `"$shown`": HTTP 404"
$failures = @(
    @{
        Block = { Add-GitHubIssueComment -Issue $issue -Body 'x' -Repository $url }
        Like  = (& $escape "Commenting on issue $shownIssue failed: gh issue comment $shownIssue --body-file ") + '*' +
        (& $escape " --repo $shown (exit 1)$printed")
        Name  = 'Add-GitHubIssueComment shows no credential in the issue, the repository, or gh''s output'
    }
    @{
        Block = {
            Close-GitHubIssue -Issue $issue -Repository $url -Comment $url -Reason duplicate `
                -DuplicateOf "$url/issues/9"
        }
        Like  = & $escape ("Closing issue $shownIssue failed: gh issue close $shownIssue --comment=$shown" +
            " --reason duplicate --duplicate-of $shown/issues/9 --repo $shown (exit 1)$printed")
        Name  = 'Close-GitHubIssue shows none in the issue, a comment, the original, the repository, or gh''s output'
    }
    @{
        Block = { Open-GitHubIssue -Issue $issue -Comment $url }
        Like  = & $escape ("Reopening issue $shownIssue failed: gh issue reopen $shownIssue --comment=$shown" +
            " (exit 1)$printed")
        Name  = 'Open-GitHubIssue shows none in the issue, a comment, or gh''s output'
    }
    @{
        Block = { Lock-GitHubIssue -Issue 7 -Repository $url -Reason spam }
        Like  = & $escape "Locking issue 7 failed: gh issue lock 7 --reason spam --repo $shown (exit 1)$printed"
        Name  = 'Lock-GitHubIssue shows none in the repository or gh''s output'
    }
    @{
        Block = { Unlock-GitHubIssue -Issue $issue }
        Like  = & $escape "Unlocking issue $shownIssue failed: gh issue unlock $shownIssue (exit 1)$printed"
        Name  = 'Unlock-GitHubIssue shows none in the issue or gh''s output'
    }
    @{
        Block = { Remove-GitHubIssue -Issue 7 -Repository $url }
        Like  = & $escape "Deleting issue 7 failed: gh issue delete 7 --yes --repo $shown (exit 1)$printed"
        Name  = 'Remove-GitHubIssue shows none in the repository or gh''s output'
    }
    @{
        Block = { Get-GitHubIssue -Issue $issue -Property title }
        Like  = & $escape ("Reading issue $shownIssue failed: gh issue view $shownIssue --json title,number,url" +
            " (exit 1)$printed")
        Name  = 'Get-GitHubIssue shows none in the issue or gh''s output'
    }
    @{
        Block = { Get-GitHubIssue -List -Search $url -Author $url -Label $url -Repository $url -Property title }
        Like  = & $escape ("Listing issues failed: gh issue list --json title,number,url --author=$shown" +
            " --search=$shown --label=$shown --repo $shown (exit 1)$printed")
        Name  = 'and the list shows none in a filter, a label, the repository, or gh''s output'
    }
    @{
        Block = { Get-GitHubIssueStatus -Repository $url -Property title }
        Like  = & $escape ("Reading issue status failed: gh issue status --json title,number,url --repo $shown" +
            " (exit 1)$printed")
        Name  = 'Get-GitHubIssueStatus shows none in the repository or gh''s output'
    }
    @{
        Block = { Set-GitHubIssue -Issue $issue -Title $url -Milestone $url -AddLabel $url }
        Like  = & $escape ("Editing issue $shownIssue failed: gh issue edit $shownIssue --title=$shown" +
            " --milestone=$shown --add-label=$shown (exit 1)$printed")
        Name  = 'Set-GitHubIssue shows none in the issue, a title, a milestone, a label, or gh''s output'
    }
    @{
        Block = { Set-GitHubIssue -Issue $issue -Pinned }
        Like  = & $escape "Pinning issue $shownIssue failed: gh issue pin $shownIssue (exit 1)$printed"
        Name  = 'and for the pin'
    }
    @{
        Block = { Move-GitHubIssue -Issue $issue -DestinationRepository $url }
        Like  = & $escape ("Transferring issue $shownIssue failed: gh issue transfer $shownIssue $shown" +
            " (exit 1)$printed")
        Name  = 'Move-GitHubIssue shows none in the issue, the destination, or gh''s output'
    }
    @{
        Block = {
            New-GitHubIssue -Title $url -Body 'b' -Repository $url -Assignee $url -Milestone $url -Parent $issue
        }
        Like  = (& $escape ("Creating the issue failed: gh issue create --title=$shown --assignee=$shown" +
            " --milestone=$shown --parent $shownIssue --body-file ")) + '*' +
        (& $escape " --repo $shown (exit 1)$printed")
        Name  = 'New-GitHubIssue shows none in the title, a person, a milestone, the parent, or gh''s output'
    }
)
try {
    # Act / Assert
    foreach ($case in $failures) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike $case.Like -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with text that is not JSON
$fake = New-FakeGitHubCli -Output @("moved $url")
$start = "gh's output is not valid JSON, starting 'moved $shown': 'm' is an invalid start"
$unreadable = @(
    @{
        Block = { Get-GitHubIssue -Issue 7 -Repository 'o/r' }
        Name  = 'Get-GitHubIssue shows no credential in an answer it cannot read'
    }
    @{
        Block = { Get-GitHubIssue -List -Repository 'o/r' }
        Name  = 'and the list shows none'
    }
    @{
        Block = { Get-GitHubIssueStatus -Repository 'o/r' }
        Name  = 'and the status shows none'
    }
)
try {
    # Act / Assert
    foreach ($case in $unreadable) {
        Assert-Throws -ScriptBlock $case.Block -MessageLike ((& $escape $start) + '*') -Message $case.Name
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
