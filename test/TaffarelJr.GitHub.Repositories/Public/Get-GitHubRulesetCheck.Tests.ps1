#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a named repository
$fake = New-FakeGitHubCli -Output @('[[{"type":"copilot_code_review","ruleset_id":123}]]')
try {
    # Act
    $rules = @(Get-GitHubRulesetCheck -Branch 'main' -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rules/branches/main?per_page=100', '--paginate', '--slurp') `
        -Actual $call.Arguments `
        -Message 'The repository and branch are embedded directly in the endpoint path'
    Assert-Equal -Expected ([long]123) -Actual $rules[0].RulesetId -Message 'Each applying rule is parsed and re-cased'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, no applying rules at all
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    $rules = @('main' | Get-GitHubRulesetCheck)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/{owner}/{repo}/rules/branches/main?per_page=100', '--paginate', '--slurp') `
        -Actual $call.Arguments `
        -Message 'The branch binds from the pipeline, and without -Repository the ambient-repo placeholder is used'
    Assert-Equal -Expected 0 -Actual $rules.Count `
        -Message 'No applying rules writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a branch name with characters a URL would read as something else
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    Get-GitHubRulesetCheck -Branch 'feature/x#1%2' -Repository 'o/r' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('api', 'repos/o/r/rules/branches/feature%2Fx%231%252?per_page=100', '--paginate', '--slurp') `
        -Actual $call.Arguments `
        -Message 'The branch is URL-encoded, so a # is not a fragment that answers for another branch'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - branch objects piped in, from an enterprise repository given as an object
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    @(
        [PSCustomObject]@{ Name = 'main' }, [PSCustomObject]@{ Name = 'release/v1' }
    ) | Get-GitHubRulesetCheck -Repository ([PSCustomObject]@{ Url = 'https://ghe.example.com/o/r' }) | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'repos/o/r/rules/branches/main?per_page=100', '--paginate', '--slurp', '--hostname',
            'ghe.example.com'
        ) `
        -Actual $calls[0].Arguments `
        -Message 'A piped branch is read by its Name, not its text, and the repository''s host goes to gh as --hostname'
    Assert-Equal `
        -Expected @(
            'api', 'repos/o/r/rules/branches/release%2Fv1?per_page=100', '--paginate', '--slurp', '--hostname',
            'ghe.example.com'
        ) `
        -Actual $calls[1].Arguments `
        -Message 'each branch in its own call'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a branch object whose Name is a number, a hashtable, and a hashtable given by parameter
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    [PSCustomObject]@{ Name = 7 } | Get-GitHubRulesetCheck -Repository 'o/r' | Out-Null
    @{ Name = 'release/v1' } | Get-GitHubRulesetCheck -Repository 'o/r' | Out-Null
    Get-GitHubRulesetCheck -Branch @{ Name = 'main' } -Repository 'o/r' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 3 -Actual $calls.Count -Message 'Each branch is checked once'
    Assert-Equal -Expected 'repos/o/r/rules/branches/7?per_page=100' -Actual $calls[0].Arguments[1] `
        -Message 'An object with a numeric Name is read by that Name, not by its text'
    Assert-Equal -Expected 'repos/o/r/rules/branches/release%2Fv1?per_page=100' -Actual $calls[1].Arguments[1] `
        -Message 'a piped hashtable by its Name'
    Assert-Equal -Expected 'repos/o/r/rules/branches/main?per_page=100' -Actual $calls[2].Arguments[1] `
        -Message 'and a hashtable given as -Branch the same'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no branch: an object without a Name, a blank Name, a list, and a switch value
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = 1 } | Get-GitHubRulesetCheck -Repository 'o/r'
    } -MessageLike '*A branch object needs a Name, and this one has none: PSCustomObject.' `
        -Message 'An object without a Name is refused, not checked under its text'
    Assert-Throws -ScriptBlock {
        @{ Name = ' ' } | Get-GitHubRulesetCheck -Repository 'o/r'
    } -MessageLike "*-Branch is blank: give the branch's name." -Message 'an object with a blank Name is blank'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch @('a', 'b') -Repository 'o/r'
    } -MessageLike '*Give one branch at a time, not a list of 2; pipe them to name several.' `
        -Message 'a list is refused rather than joined into one name'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch $true -Repository 'o/r'
    } -MessageLike "*'True' is not a branch name: give the branch's name, or a branch object." `
        -Message 'and so is a switch value'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host for the current directory's repository, and HOST/OWNER/REPO
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    Get-GitHubRulesetCheck -Branch 'main' -Hostname 'ghe.example.com' | Out-Null
    Get-GitHubRulesetCheck -Branch 'main' -Repository 'github.com/o/r' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @(
            'api', 'repos/{owner}/{repo}/rules/branches/main?per_page=100', '--paginate', '--slurp', '--hostname',
            'ghe.example.com'
        ) `
        -Actual $calls[0].Arguments `
        -Message '-Hostname alone asks that host about the current directory''s repository'
    Assert-Equal `
        -Expected @(
            'api', 'repos/o/r/rules/branches/main?per_page=100', '--paginate', '--slurp', '--hostname', 'github.com'
        ) `
        -Actual $calls[1].Arguments `
        -Message 'and a host in front of OWNER/REPO is put apart from the path'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository that would change the endpoint's path, and one given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch 'main' -Repository 'o/r/../../x'
    } -MessageLike "*'o/r/../../x' is not a repository the API can be asked about*" `
        -Message 'A repository that is not OWNER/REPO is refused, so it cannot reach another endpoint'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch 'main' -Hostname 'ghe.example.com:8443'
    } -MessageLike "*'ghe.example.com:8443' is not a host name: give it bare*" `
        -Message 'A host with a port is refused by Core''s host name check'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch 'main' -Hostname '-x'
    } -MessageLike "*'-x' is not a host name*" -Message 'as is one gh would read as an option'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch ' '
    } -MessageLike "*-Branch is blank: give the branch's name." -Message 'A blank branch is refused, not checked as %20'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch ''
    } -MessageLike "*-Branch is blank: give the branch's name." -Message 'as is an empty one'
    Assert-Throws -ScriptBlock {
        Get-GitHubRulesetCheck -Branch 'main' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of checking the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
