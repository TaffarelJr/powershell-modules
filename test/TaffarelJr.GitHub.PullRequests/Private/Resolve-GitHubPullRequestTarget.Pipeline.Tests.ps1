#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# Every function that acts on one pull request, with the arguments it needs
# besides the pull request. Each puts the operand straight after its
# subcommand.
$functions = @(
    @{ Name = 'Add-GitHubPullRequestComment'; Extra = @{ Body = 'hi' } }
    @{ Name = 'Close-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Get-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Get-GitHubPullRequestCheck'; Extra = @{} }
    @{ Name = 'Get-GitHubPullRequestDiff'; Extra = @{} }
    @{ Name = 'Lock-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Merge-GitHubPullRequest'; Extra = @{ Strategy = 'squash' } }
    @{ Name = 'Open-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Set-GitHubPullRequest'; Extra = @{ Title = 'x' } }
    @{ Name = 'Submit-GitHubPullRequestReview'; Extra = @{ Decision = 'Approve' } }
    @{ Name = 'Switch-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Unlock-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Update-GitHubPullRequestBranch'; Extra = @{} }
)

# The ones whose pull request may be left out for the current branch's.
$optional = @(
    @{ Name = 'Add-GitHubPullRequestComment'; Extra = @{ Body = 'hi' } }
    @{ Name = 'Get-GitHubPullRequest'; Extra = @{} }
    @{ Name = 'Get-GitHubPullRequestCheck'; Extra = @{} }
    @{ Name = 'Get-GitHubPullRequestDiff'; Extra = @{} }
    @{ Name = 'Merge-GitHubPullRequest'; Extra = @{ Strategy = 'squash' } }
    @{ Name = 'Set-GitHubPullRequest'; Extra = @{ Ready = $true } }
    @{ Name = 'Submit-GitHubPullRequestReview'; Extra = @{ Decision = 'Approve' } }
    @{ Name = 'Update-GitHubPullRequestBranch'; Extra = @{} }
)

# gh's lock and unlock read an issue number or URL, never a branch name.
$byBranch = @($functions | Where-Object { $_.Name -notmatch '^(Lock|Unlock)-' })
$noBranch = @($functions | Where-Object { $_.Name -match '^(Lock|Unlock)-' })

function Get-OperandSent {
    param($Function, $PullRequest, [switch]$Piped)

    $fake = New-FakeGitHubCli -Output @('[]')
    try {
        $extra = $Function.Extra
        if ($Piped) {
            $PullRequest | & $Function.Name @extra | Out-Null
        }
        else {
            & $Function.Name -PullRequest $PullRequest @extra | Out-Null
        }

        return @(Get-FakeGitHubCall -Fixture $fake)
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

$listed = [PSCustomObject]@{
    Number = 7
    Url    = 'https://github.com/o/other/pull/7'
    Title  = 'A listed pull request'
}
$numberOnly = [PSCustomObject]@{ Number = 8 }
$fromApi = [PSCustomObject]@{
    number   = 5
    url      = 'https://api.github.com/repos/o/r/pulls/5'
    html_url = 'https://github.com/o/r/pull/5'
}
$eventPayload = @{
    number = 9
    url    = 'https://api.github.com/repos/o/r/pulls/9'
}

foreach ($function in $functions) {
    #───────────────────────────────────────────────────────────────────────────
    # Act - pull request objects piped in, as a listing or a search returns them
    $calls = Get-OperandSent -Function $function -PullRequest @($listed, $numberOnly) -Piped

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count `
        -Message "$($function.Name): each piped object is acted on in its own call"
    Assert-Equal -Expected 'https://github.com/o/other/pull/7' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): an object is read by its Url, not by the text of the object"
    Assert-Equal -Expected '8' -Actual $calls[1].Arguments[2] `
        -Message "$($function.Name): one with only a Number is read by that"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a raw API pull request, and an Actions event payload's hashtable
    $calls = Get-OperandSent -Function $function -PullRequest @($fromApi, $eventPayload) -Piped

    # Assert
    Assert-Equal -Expected 'https://github.com/o/r/pull/5' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): a raw API object is read by its html_url, not its REST url"
    Assert-Equal -Expected '9' -Actual $calls[1].Arguments[2] `
        -Message "$($function.Name): a hashtable with only a REST url is read by its number"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a number given as the argument
    $byNumber = Get-OperandSent -Function $function -PullRequest '#12'

    # Assert
    Assert-Equal -Expected '12' -Actual $byNumber[0].Arguments[2] `
        -Message "$($function.Name): a number written with its # is passed without it"
}

foreach ($function in $byBranch) {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a branch name given as the argument
    $calls = Get-OperandSent -Function $function -PullRequest 'feature/x'

    # Assert
    Assert-Equal -Expected 'feature/x' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): a branch name is passed to gh as it is"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a branch name for a function whose gh command takes none
$fake = New-FakeGitHubCli
try {
    foreach ($function in $noBranch) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest 'feature' @extra
        } -MessageLike "'feature' is not a pull request: give its number or URL, as gh takes no branch name here." `
            -Message "$($function.Name): a branch name is refused, rather than failing in gh as an invalid issue"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is called for neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a pull request of this repository, for each
# function in turn
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest '--web' @extra
        } -MessageLike "'--web' is not a pull request: give its number, URL, or branch name, or a pull request object." `
            -Message "$($function.Name): a pull request that is a gh option is refused"
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest ([PSCustomObject]@{ Number = '#7' }) @extra
        } -MessageLike "'#7' is not a pull request number: an object's Number must be a whole number of 1 to 10 digits." `
            -Message "$($function.Name): an object whose Number is not a whole number is refused, not read as a branch name"
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest 'https://github.com/o/r/issues/5' @extra
        } -MessageLike "*'https://github.com/o/r/issues/5' is an issue, not a pull request*" `
            -Message "$($function.Name): an issue URL is refused, rather than looked up as a branch"
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest 'https://github.com/a/b/pull/5' -Repository 'c/d' @extra
        } -MessageLike "*is in a/b, but -Repository names c/d*" `
            -Message "$($function.Name): a URL of another repository than -Repository is refused"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pull request given, but $null - a lookup that came back empty
$fake = New-FakeGitHubCli
try {
    foreach ($function in $optional) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest $null @extra
        } -MessageLike "*A pull request was given, but it is `$null - leave it out to use the current branch's pull request.*" `
            -Message "$($function.Name): a `$null argument is refused, not taken for the current branch's pull request"
        Assert-Throws -ScriptBlock {
            $null | & $function.Name @extra
        } -MessageLike '*A pull request was given, but it is $null*' `
            -Message "$($function.Name): and so is a piped `$null"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository but no pull request, which gh refuses
$fake = New-FakeGitHubCli
try {
    foreach ($function in $optional) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -Repository 'o/r' @extra
        } -MessageLike "-Repository o/r was given without a pull request, and gh needs one named along with --repo. Give -PullRequest, or leave out -Repository to use the current branch's pull request." `
            -Message "$($function.Name): -Repository without a pull request is refused before gh runs"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every function of the module, with what it needs besides -Repository
$everyFunction = @(
    foreach ($function in $functions) {
        @{ Name = $function.Name; Extra = $function.Extra + @{ PullRequest = 12 } }
    }
    @{ Name = 'New-GitHubPullRequest'; Extra = @{ Fill = $true } }
    @{ Name = 'Get-GitHubPullRequestStatus'; Extra = @{} }
)
$repository = [PSCustomObject]@{ Url = 'https://github.com/o/r'; NameWithOwner = 'o/r' }
$fake = New-FakeGitHubCli -Output @('[]')
try {
    foreach ($function in $everyFunction) {
        $extra = $function.Extra

        # Act
        & $function.Name -Repository $repository @extra | Out-Null
        $call = @(Get-FakeGitHubCall -Fixture $fake)[-1]

        # Assert
        Assert-Equal -Expected @('--repo', 'https://github.com/o/r') -Actual $call.Arguments[-2..-1] `
            -Message "$($function.Name): a repository object is read by its Url, not sent as the text of the object"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a list of repositories, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    foreach ($function in $everyFunction) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -Repository 'a/b', 'c/d' @extra
        } -MessageLike 'Give one repository at a time, not a list of 2; call once per repository.' `
            -Message "$($function.Name): a list of repositories is refused"
        Assert-Throws -ScriptBlock {
            & $function.Name -Repository $null @extra
        } -MessageLike "-Repository was given, but it is `$null - leave it out to use the current directory's repository." `
            -Message "$($function.Name): a repository given as `$null is refused, not taken for the current directory's"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot find the pull request
$fake = New-FakeGitHubCli `
    -ErrorOutput @('GraphQL: Could not resolve to a PullRequest with the number of 99. (repository.pullRequest)') `
    -ExitCode 1
try {
    foreach ($function in $functions) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -PullRequest 99 @extra
        } -MessageLike '*pull request 99 failed*Could not resolve to a PullRequest with the number of 99*' `
            -Message "$($function.Name): a failure names the pull request and carries the message from gh"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
