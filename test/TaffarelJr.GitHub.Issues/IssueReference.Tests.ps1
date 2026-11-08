#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every function that acts on one issue, with the arguments it needs besides
# the issue. Each puts the issue's reference straight after its subcommand.
$functions = @(
    @{ Name = 'Add-GitHubIssueComment'; Extra = @{ Body = 'hi' } }
    @{ Name = 'Close-GitHubIssue'; Extra = @{} }
    @{ Name = 'Get-GitHubIssue'; Extra = @{} }
    @{ Name = 'Lock-GitHubIssue'; Extra = @{} }
    @{ Name = 'Move-GitHubIssue'; Extra = @{ DestinationRepository = 'o/other' } }
    @{ Name = 'Open-GitHubIssue'; Extra = @{} }
    @{ Name = 'Remove-GitHubIssue'; Extra = @{} }
    @{ Name = 'Set-GitHubIssue'; Extra = @{ Title = 'x' } }
    @{ Name = 'Unlock-GitHubIssue'; Extra = @{} }
)

function Get-IssueReferenceSent {
    param($Function, $Issue, [hashtable]$Options = @{}, [switch]$Piped)

    $fake = New-FakeGitHubCli -Output @('{"number":1}')
    try {
        $extra = $Function.Extra
        if ($Piped) {
            $Issue | & $Function.Name @extra @Options | Out-Null
        }
        else {
            & $Function.Name -Issue $Issue @extra @Options | Out-Null
        }

        return @(Get-FakeGitHubCall -Fixture $fake)
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

$issueObject = [PSCustomObject]@{ Number = 7; Url = 'https://github.com/o/other/issues/7'; Title = 'A listed issue' }
$numberOnly = [PSCustomObject]@{ Number = 8 }

foreach ($function in $functions) {
    #───────────────────────────────────────────────────────────────────────────
    # Act - issue objects piped in, as a listing or a search returns them
    $calls = Get-IssueReferenceSent -Function $function -Issue @($issueObject, $numberOnly) -Piped

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count `
        -Message "$($function.Name): each piped issue object is acted on in its own call"
    Assert-Equal -Expected 'https://github.com/o/other/issues/7' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): an object is read by its Url, not by the text of the object"
    Assert-Equal -Expected '8' -Actual $calls[1].Arguments[2] `
        -Message "$($function.Name): one with only a Number is read by that"

    #───────────────────────────────────────────────────────────────────────────
    # Act - bare numbers piped in
    $calls = Get-IssueReferenceSent -Function $function -Issue @(3, '4') -Piped

    # Assert
    Assert-Equal -Expected @('3', '4') -Actual @($calls.ForEach({ $_.Arguments[2] })) `
        -Message "$($function.Name): numbers piped in are the issues, whether they are numbers or text"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a URL given as the argument, with the repository it is in
    $options = @{ Repository = 'o/r' }
    $calls = Get-IssueReferenceSent -Function $function -Issue 'https://github.com/o/r/issues/12#issuecomment-1' `
        -Options $options

    # Assert
    Assert-Equal -Expected 'https://github.com/o/r/issues/12#issuecomment-1' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): a URL is passed to gh as it is, a fragment included"
    Assert-Equal -Expected @('--repo', 'o/r') -Actual @($calls[0].Arguments[-2..-1]) `
        -Message "$($function.Name): and so is a -Repository that agrees with it"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a hashtable given as the argument
    $calls = Get-IssueReferenceSent -Function $function -Issue @{ Number = 9 }

    # Assert
    Assert-Equal -Expected '9' -Actual $calls[0].Arguments[2] `
        -Message "$($function.Name): a hashtable is read by its Number"

    #───────────────────────────────────────────────────────────────────────────
    # Act - the repository given as a repository object, as a listing returns it
    $options = @{ Repository = [PSCustomObject]@{ Url = 'https://github.com/o/r'; NameWithOwner = 'o/r' } }
    $calls = Get-IssueReferenceSent -Function $function -Issue 5 -Options $options

    # Assert
    $expected = @('--repo', 'https://github.com/o/r')
    Assert-Equal -Expected $expected -Actual @($calls[0].Arguments[-2..-1]) `
        -Message "$($function.Name): a repository object is read by its Url, not by its text"

    #───────────────────────────────────────────────────────────────────────────
    # Act - the repository given as text with spaces around it, and as a URL
    # ending in .git, with an issue URL in that repository
    $calls = Get-IssueReferenceSent -Function $function -Issue 5 -Options @{ Repository = ' o/r ' }
    $options = @{ Repository = 'https://github.com/o/r.git' }
    $urlCalls = Get-IssueReferenceSent -Function $function -Issue 'https://github.com/o/r/issues/5' -Options $options

    # Assert
    Assert-Equal -Expected @('--repo', 'o/r') -Actual @($calls[0].Arguments[-2..-1]) `
        -Message "$($function.Name): -Repository reaches gh trimmed"
    $expected = @('--repo', 'https://github.com/o/r.git')
    Assert-Equal -Expected $expected -Actual @($urlCalls[0].Arguments[-2..-1]) `
        -Message "$($function.Name): a .git URL names the same repository as the issue's URL"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories that name no one repository, for each function in turn
$refusedRepositories = @(
    @{
        Repository = $null
        Pattern    = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message    = 'A -Repository given as $null is refused, not taken for the current directory''s'
    }
    @{
        Repository = @('a/b', 'c/d')
        Pattern    = 'Give one repository at a time, not a list of 2; call once per repository.'
        Message    = 'as are several repositories at once'
    }
    @{
        Repository = '-x'
        Pattern    = "'-x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        Message    = 'and one gh would read as an option'
    }
)
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        foreach ($case in $refusedRepositories) {
            $extra = $function.Extra

            # Act / Assert
            Assert-Throws -ScriptBlock {
                5 | & $function.Name @extra -Repository $case.Repository
            } -MessageLike $case.Pattern -Message "$($function.Name): $($case.Message)"
        }
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no issue, or a pull request, for each function in turn
$refused = @(
    @{
        Issue   = '--web'
        Options = @{}
        Pattern = "'--web' is not an issue: give its number or URL, or an issue object."
        Message = 'an issue that is a gh option is refused'
    }
    @{
        Issue   = [string][char]0x0663
        Options = @{}
        Pattern = "'$([char]0x0663)' is not an issue: give its number or URL, or an issue object."
        Message = 'as is a digit gh does not read'
    }
    @{
        Issue   = 'https://github.com/o/r'
        Options = @{}
        Pattern = "'https://github.com/o/r' is not an issue: a URL must end in /OWNER/REPO/issues/NUMBER."
        Message = 'A repository URL is no issue'
    }
    @{
        Issue   = 'https://github.com/o/r/pull/5'
        Options = @{}
        Pattern = '*is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests for it.*'
        Message = 'A pull request URL is refused, so gh never acts on the pull request'
    }
    @{
        Issue   = [PSCustomObject]@{ Number = 5; IsPullRequest = $true }
        Options = @{}
        Pattern = '*This object is a pull request, not an issue*'
        Message = 'as is a search result that is a pull request'
    }
    @{
        Issue   = @(1, 2)
        Options = @{}
        Pattern = 'Give one issue at a time, not a list of 2; pipe them to name several.'
        Message = 'Several issues given at once are refused, naming the kind and pointing at piping them'
    }
    @{
        Issue   = 'https://github.com/a/b/issues/1'
        Options = @{ Repository = 'c/d' }
        Pattern = "'https://github.com/a/b/issues/1' is in a/b, but -Repository names c/d: give one or the other."
        Message = 'A URL in another repository than -Repository is refused, as gh would ignore -Repository'
    }
)
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        foreach ($case in $refused) {
            $extra = $function.Extra
            $options = $case.Options

            # Act / Assert
            Assert-Throws -ScriptBlock {
                & $function.Name -Issue $case.Issue @extra @options
            } -MessageLike $case.Pattern -Message "$($function.Name): $($case.Message)"
        }
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing of chosen fields, leaving url out, from another repository
$listing = '[{"number":5,"url":"https://github.com/other/repo/issues/5"}]'
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($listing) }, @{ Output = @() })
try {
    # Act
    Get-GitHubIssue -List -Property 'number' -Repository 'other/repo' | Close-GitHubIssue
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @('issue', 'list', '--json', 'number,url', '--repo', 'other/repo')
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'A listing asks for url whatever -Property says'
    $expected = @('issue', 'close', 'https://github.com/other/repo/issues/5')
    Assert-Equal -Expected $expected -Actual $calls[1].Arguments `
        -Message 'so an issue piped on is acted on in the repository it came from, not the current one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot find the issue
$fake = New-FakeGitHubCli `
    -ErrorOutput @('GraphQL: Could not resolve to an issue with the number of 99. (repository.issue)') `
    -ExitCode 1
try {
    foreach ($function in $functions) {
        $extra = $function.Extra

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $function.Name -Issue 99 @extra
        } -MessageLike '*issue 99 failed*Could not resolve to an issue with the number of 99*' `
            -Message "$($function.Name): a failure throws with the message from gh, naming the issue"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
