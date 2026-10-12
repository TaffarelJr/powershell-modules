#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$clock = Use-FakePollClock -Module $module

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$other = 'https://v:SENTINEL@ghe.example.com/o/other'
$otherShown = 'https://***@ghe.example.com/o/other'
$pull = "$url/pull/7"
$pullShown = "$shown/pull/7"
$bare = 'user:SENTINEL@h.example'
$bareShown = '***@h.example'
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run
$fake = New-FakeGitHubCli
try {
    $withoutPullRequest = "-Repository ghe.example.com/o/r was given without a pull request, and gh needs one named" +
    " along with --repo. Give -PullRequest, or leave out -Repository to use the current branch's pull request."
    $noBranch = "'$bareShown' is not a pull request: give its number or URL, as gh takes no branch name here."
    $notPullRequest = "'$shown/issues/x' is not a pull request: a URL must end in /OWNER/REPO/pull/NUMBER."
    $mismatch = "'$pullShown' is in ghe.example.com/o/r, but -Repository names ${otherShown}: give one or the other."
    $notRepository = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    $messages = @(
        @{
            Block    = { Add-GitHubPullRequestComment -Body 'b' -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Add-GitHubPullRequestComment, for a -Repository with no pull request'
        }
        @{
            Block    = { Get-GitHubPullRequest -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Get-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestCheck -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Get-GitHubPullRequestCheck, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestDiff -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Get-GitHubPullRequestDiff, for the same'
        }
        @{
            Block    = { Merge-GitHubPullRequest -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Merge-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Set-GitHubPullRequest -Ready -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Set-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Submit-GitHubPullRequestReview -Decision Approve -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Submit-GitHubPullRequestReview, for the same'
        }
        @{
            Block    = { Update-GitHubPullRequestBranch -Repository $url }
            Expected = $withoutPullRequest
            Name     = 'Update-GitHubPullRequestBranch, for the same'
        }
        @{
            Block    = { Lock-GitHubPullRequest -PullRequest $bare }
            Expected = $noBranch
            Name     = 'Lock-GitHubPullRequest, for a branch name where gh takes none'
        }
        @{
            Block    = { Unlock-GitHubPullRequest -PullRequest $bare }
            Expected = $noBranch
            Name     = 'Unlock-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Add-GitHubPullRequestComment -PullRequest "$url/issues/x" -Body 'b' }
            Expected = $notPullRequest
            Name     = 'Add-GitHubPullRequestComment, for a URL that is not a pull request''s'
        }
        @{
            Block    = { Close-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Close-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Get-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestCheck -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Get-GitHubPullRequestCheck, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestDiff -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Get-GitHubPullRequestDiff, for the same'
        }
        @{
            Block    = { Lock-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Lock-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Merge-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Merge-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Open-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Open-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Set-GitHubPullRequest -PullRequest "$url/issues/x" -Title 't' }
            Expected = $notPullRequest
            Name     = 'Set-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Submit-GitHubPullRequestReview -PullRequest "$url/issues/x" -Decision Approve }
            Expected = $notPullRequest
            Name     = 'Submit-GitHubPullRequestReview, for the same'
        }
        @{
            Block    = { Switch-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Switch-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Unlock-GitHubPullRequest -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Unlock-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Update-GitHubPullRequestBranch -PullRequest "$url/issues/x" }
            Expected = $notPullRequest
            Name     = 'Update-GitHubPullRequestBranch, for the same'
        }
        @{
            Block    = { Close-GitHubPullRequest -PullRequest $pull -Repository $other }
            Expected = $mismatch
            Name     = 'Close-GitHubPullRequest, for a URL from another repository than -Repository'
        }
        @{
            Block    = { Get-GitHubPullRequest -PullRequest $pull -Repository $other }
            Expected = $mismatch
            Name     = 'Get-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Add-GitHubPullRequestComment -Body 'b' -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Add-GitHubPullRequestComment, for a -Repository that is not one'
        }
        @{
            Block    = { Close-GitHubPullRequest -PullRequest 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Close-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequest -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestCheck -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubPullRequestCheck, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestDiff -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubPullRequestDiff, for the same'
        }
        @{
            Block    = { Get-GitHubPullRequestStatus -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Get-GitHubPullRequestStatus, for the same'
        }
        @{
            Block    = { Lock-GitHubPullRequest -PullRequest 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Lock-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Merge-GitHubPullRequest -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Merge-GitHubPullRequest, for the same'
        }
        @{
            Block    = { New-GitHubPullRequest -Repository "$url x" }
            Expected = $notRepository
            Name     = 'New-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Open-GitHubPullRequest -PullRequest 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Open-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Set-GitHubPullRequest -Title 't' -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Set-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Submit-GitHubPullRequestReview -Decision Approve -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Submit-GitHubPullRequestReview, for the same'
        }
        @{
            Block    = { Switch-GitHubPullRequest -PullRequest 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Switch-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Unlock-GitHubPullRequest -PullRequest 7 -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Unlock-GitHubPullRequest, for the same'
        }
        @{
            Block    = { Update-GitHubPullRequestBranch -Repository "$url x" }
            Expected = $notRepository
            Name     = 'Update-GitHubPullRequestBranch, for the same'
        }
    )

    # Act / Assert
    foreach ($case in $messages) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is called for none'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, whose targets and actions show a branch name, a URL, a
# title, and a branch the caller gave
$fake = New-FakeGitHubCli
try {
    $here = (Get-Location).ProviderPath

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest $bare -Body 'b' -Repository 'o/r' -WhatIf
        Close-GitHubPullRequest -PullRequest $bare -Repository 'o/r' -WhatIf
        Merge-GitHubPullRequest -PullRequest $bare -Repository 'o/r' -WhatIf
        Open-GitHubPullRequest -PullRequest $bare -Repository 'o/r' -WhatIf
        Set-GitHubPullRequest -PullRequest $bare -Title 't' -Repository 'o/r' -WhatIf
        Submit-GitHubPullRequestReview -PullRequest $bare -Decision Approve -Repository 'o/r' -WhatIf
        Switch-GitHubPullRequest -PullRequest $bare -Repository 'o/r' -WhatIf
        Update-GitHubPullRequestBranch -PullRequest $bare -Repository 'o/r' -WhatIf
        Lock-GitHubPullRequest -PullRequest $pull -WhatIf
        Unlock-GitHubPullRequest -PullRequest $pull -WhatIf
        New-GitHubPullRequest -Title 'user:SENTINEL@h.example' -Head 'u2:SENTINEL@i.example' `
            -Base 'u3:SENTINEL@j.example' -Repository $url -WhatIf
    }

    # Assert
    $on = 'o/r pull request ***@h.example'
    $expected = @(
        "What if: Performing the operation `"Add comment`" on target `"$on`"."
        "What if: Performing the operation `"Close pull request`" on target `"$on`"."
        "What if: Performing the operation `"Merge pull request`" on target `"$on`"."
        "What if: Performing the operation `"Reopen pull request`" on target `"$on`"."
        "What if: Performing the operation `"Edit pull request`" on target `"$on`"."
        "What if: Performing the operation `"Approve pull request`" on target `"$on`"."
        "What if: Performing the operation `"Check out $on`" on target `"$here`"."
        "What if: Performing the operation `"Merge the base branch into the head branch`" on target `"$on`"."
        "What if: Performing the operation `"Lock pull request`" on target `"ghe.example.com/o/r pull request #7`"."
        "What if: Performing the operation `"Unlock pull request`" on target `"ghe.example.com/o/r pull request #7`"."
        'What if: Performing the operation "Create pull request ''***@h.example'' from ***@i.example into' +
        ' ***@j.example" on target "ghe.example.com/o/r".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf shows no credential in a branch name, a URL, a title, a head or a base branch'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf for a checkout into a branch and a worktree whose names hold
# a credential, in the folder's own separator
$fake = New-FakeGitHubCli
try {
    $separator = [IO.Path]::DirectorySeparatorChar

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Switch-GitHubPullRequest -PullRequest 12 -Branch $bare -Worktree 'SENTINEL@h.example/wt' `
            -Repository 'o/r' -WhatIf
    }

    # Assert
    $line = @($whatIf.Messages)[0]
    $pattern = [WildcardPattern]::Escape(
        'What if: Performing the operation "Check out o/r pull request #12 as branch ***@h.example' +
        ' into a new worktree" on target "') + '*' + [WildcardPattern]::Escape("***@h.example${separator}wt`".")
    Assert-That -Condition ($whatIf.Messages.Count -eq 1 -and $line -like $pattern) `
        -Message '-WhatIf names the branch, and the worktree keeping what follows the credential'
    Assert-That -Condition ($line -notmatch 'SENTINEL') -Message 'without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a worktree that is a drive-qualified path holding a credential, which PowerShell cannot read
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    & $assertMessage {
        Switch-GitHubPullRequest -PullRequest 12 -Worktree 'u:SENTINEL@h.example/wt'
    } "'***@h.example/wt' is not a path PowerShell can read, so gh cannot use it." `
        'A worktree PowerShell cannot read is refused, its message showing no credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL, given the URL in every place a
# call carries one
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Forbidden $url") -ExitCode 1
try {
    $tail = "`ngh: Forbidden $shown"
    $failures = @(
        @{
            Block    = { Close-GitHubPullRequest -PullRequest $pull -Comment "see $url" -DeleteBranch -Repository $url }
            Expected = "Closing pull request $pullShown failed: gh pr close $pullShown '--comment=see $shown'" +
            " --delete-branch --repo $shown (exit 1)$tail"
            Name     = 'Close-GitHubPullRequest'
        }
        @{
            Block    = { Get-GitHubPullRequest -PullRequest $pull -Property 'number,url' -Repository $url }
            Expected = "Reading pull request $pullShown failed: gh pr view $pullShown --json number,url" +
            " --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubPullRequest, for one pull request'
        }
        @{
            Block    = { Get-GitHubPullRequest -PullRequest $bare -Property 'number,url' }
            Expected = "Reading pull request $bareShown failed: gh pr view $bareShown --json number,url (exit 1)$tail"
            Name     = 'and for a branch name'
        }
        @{
            Block    = {
                Get-GitHubPullRequest -List -Property 'number,url' -Base $url -Head $url -Author $url -Assignee $url `
                    -Label $url -Search $url -Repository $url
            }
            Expected = "Listing pull requests failed: gh pr list --json number,url --base=$shown --head=$shown" +
            " --author=$shown --assignee=$shown --label=$shown --search=$shown --repo $shown (exit 1)$tail"
            Name     = 'and for a list'
        }
        @{
            Block    = { Get-GitHubPullRequestCheck -PullRequest $pull -Repository $url }
            Expected = "Reading the checks of pull request $pullShown failed: gh pr checks $pullShown --json" +
            ' bucket,completedAt,description,event,link,name,startedAt,state,workflow' +
            " --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubPullRequestCheck'
        }
        @{
            Block    = { Get-GitHubPullRequestCheck -PullRequest $pull -Wait -Repository $url }
            Expected = "Could not read the checks of pull request $pullShown (exit 1):$tail"
            Name     = 'and with -Wait'
        }
        @{
            Block    = { Get-GitHubPullRequestDiff -PullRequest $pull -Exclude $url -Repository $url }
            Expected = "Reading the diff of pull request $pullShown failed: gh pr diff $pullShown --color never" +
            " --exclude=$shown --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubPullRequestDiff'
        }
        @{
            Block    = { Get-GitHubPullRequestStatus -Property 'number' -Repository $url }
            Expected = "Reading pull request status failed: gh pr status --json number,url --repo $shown (exit 1)$tail"
            Name     = 'Get-GitHubPullRequestStatus'
        }
        @{
            Block    = { Lock-GitHubPullRequest -PullRequest $pull -Reason spam -Repository $url }
            Expected = "Locking pull request $pullShown failed: gh pr lock $pullShown --reason spam" +
            " --repo $shown (exit 1)$tail"
            Name     = 'Lock-GitHubPullRequest'
        }
        @{
            Block    = {
                Merge-GitHubPullRequest -PullRequest $pull -Strategy squash -Subject "s $url" -MatchHeadCommit $url `
                    -Repository $url
            }
            Expected = "Merging pull request $pullShown failed: gh pr merge $pullShown --squash '--subject=s $shown'" +
            " --match-head-commit=$shown --repo $shown (exit 1)$tail"
            Name     = 'Merge-GitHubPullRequest'
        }
        @{
            Block    = {
                New-GitHubPullRequest -Title "t $url" -Head $url -Base $url -Label $url -Milestone $url `
                    -Repository $url
            }
            Expected = "Creating the pull request failed: gh pr create '--title=t $shown' --base=$shown --head=$shown" +
            " --label=$shown --milestone=$shown --repo $shown (exit 1)$tail"
            Name     = 'New-GitHubPullRequest'
        }
        @{
            Block    = { Open-GitHubPullRequest -PullRequest $pull -Comment "see $url" -Repository $url }
            Expected = "Reopening pull request $pullShown failed: gh pr reopen $pullShown '--comment=see $shown'" +
            " --repo $shown (exit 1)$tail"
            Name     = 'Open-GitHubPullRequest'
        }
        @{
            Block    = {
                Set-GitHubPullRequest -PullRequest $pull -Title "t $url" -Base $url -Milestone $url -AddLabel $url `
                    -Repository $url
            }
            Expected = "Editing pull request $pullShown failed: gh pr edit $pullShown '--title=t $shown'" +
            " --base=$shown --milestone=$shown --add-label=$shown --repo $shown (exit 1)$tail"
            Name     = 'Set-GitHubPullRequest'
        }
        @{
            Block    = { Submit-GitHubPullRequestReview -PullRequest $pull -Decision Approve -Repository $url }
            Expected = "Reviewing pull request $pullShown failed: gh pr review $pullShown --approve" +
            " --repo $shown (exit 1)$tail"
            Name     = 'Submit-GitHubPullRequestReview'
        }
        @{
            Block    = { Switch-GitHubPullRequest -PullRequest $pull -Branch $url -Repository $url }
            Expected = "Checking out pull request $pullShown failed: gh pr checkout $pullShown --branch=$shown" +
            " --repo $shown (exit 1)$tail"
            Name     = 'Switch-GitHubPullRequest'
        }
        @{
            Block    = { Unlock-GitHubPullRequest -PullRequest $pull -Repository $url }
            Expected = "Unlocking pull request $pullShown failed: gh pr unlock $pullShown --repo $shown (exit 1)$tail"
            Name     = 'Unlock-GitHubPullRequest'
        }
        @{
            Block    = { Update-GitHubPullRequestBranch -PullRequest $pull -Rebase -Repository $url }
            Expected = "Updating the branch of pull request $pullShown failed: gh pr update-branch $pullShown" +
            " --rebase --repo $shown (exit 1)$tail"
            Name     = 'Update-GitHubPullRequestBranch'
        }
    )

    # Act / Assert
    foreach ($case in $failures) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential in a failed call"
    }

    # Act / Assert
    $commentPattern = [WildcardPattern]::Escape("Commenting on pull request $pullShown failed:" +
        " gh pr comment $pullShown --body-file ") +
    '*' + [WildcardPattern]::Escape(" --repo $shown (exit 1)$tail")
    Assert-Throws -ScriptBlock {
        Add-GitHubPullRequestComment -PullRequest $pull -Body 'b' -Repository $url
    } -MessageLike $commentPattern -Message 'Add-GitHubPullRequestComment shows no credential in a failed call'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an edit that works, and then a change of the draft state that fails
$fake = New-FakeGitHubCli -Sequence @(
    @{ ExitCode = 0 }
    @{ ErrorOutput = @("gh: Forbidden $url"); ExitCode = 1 }
)
try {
    $expected = "Pull request $pullShown was edited, but changing its draft state failed:" +
    " Changing the draft state of pull request $pullShown failed: gh pr ready $pullShown --repo $shown (exit 1)" +
    "`ngh: Forbidden $shown"

    # Act / Assert
    & $assertMessage {
        Set-GitHubPullRequest -PullRequest $pull -Title 't' -Ready -Repository $url
    } $expected 'Set-GitHubPullRequest shows no credential in what it says was edited before the failure'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a check named with the URL that stays pending, on a clock that moves
# only when the wait sleeps
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @("[{`"name`":`"build $url`",`"state`":`"PENDING`",`"bucket`":`"pending`"}]")
try {
    $expected = "The checks of pull request $pullShown were still pending after 1 s: build $shown." +
    ' Give a longer -TimeoutSeconds to wait more.'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest $pull -Wait -PollSeconds 30 -TimeoutSeconds 1
    } -ExceptionType ([TimeoutException]) -MessageLike ([WildcardPattern]::Escape($expected)) `
        -Message 'Get-GitHubPullRequestCheck shows no credential in the pull request or a check it still waits for'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pull request that no check is ever reported on
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @('[]')
try {
    $expected = "No checks of pull request $pullShown were reported within 1 s." +
    ' Give a longer -TimeoutSeconds to wait more.'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest $pull -Wait -PollSeconds 30 -TimeoutSeconds 1
    } -ExceptionType ([TimeoutException]) -MessageLike ([WildcardPattern]::Escape($expected)) `
        -Message 'and none in the pull request it never saw a check of'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
