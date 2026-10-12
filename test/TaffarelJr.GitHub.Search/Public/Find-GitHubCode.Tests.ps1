#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'path,repository,sha,textMatches,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"path":"src/x.ps1","sha":"abc"}]')
try {
    # Act
    $results = @(Find-GitHubCode -Query 'Invoke-GitHubCommand' -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'code', '--json', $fields, '--repo', 'o/r', '--', 'Invoke-GitHubCommand') `
        -Actual $call.Arguments `
        -Message 'The repository filter goes through --repo, and the query comes last, after a --'
    Assert-Equal -Expected 'src/x.ps1' -Actual $results[0].Path -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other filter
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $results = @(Find-GitHubCode -Query 'TODO' -Owner @('o1') -Language PowerShell -Filename 'Invoke-*.ps1' -Extension 'ps1' -Match @('File', 'path') -Size '<10' -Limit 5)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'search', 'code', '--json', $fields, '--owner', 'o1', '--language', 'PowerShell', '--filename',
            'Invoke-*.ps1', '--extension', 'ps1', '--match', 'file', '--match', 'path', '--size', '<10', '--limit', '5',
            '--', 'TODO'
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, a choice in lower case'
    Assert-Equal -Expected 0 -Actual $results.Count -Message 'No results writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters alone, in several repositories
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubCode -Repository 'a/b', 'c/d' -Filename 'shared.go' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('search', 'code', '--json', $fields, '--repo', 'a/b', '--repo', 'c/d', '--filename', 'shared.go') `
        -Actual $call.Arguments `
        -Message 'Code is searched by filters alone, with no query, and each repository is a --repo of its own'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several keywords, a phrase, and an exclusion
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubCode -Query 'react lint', 'hook', '-language:go' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'code', '--json', $fields, '--', 'react lint', 'hook', '-language:go') `
        -Actual $call.Arguments `
        -Message 'Each value is one keyword, so a phrase stays whole and an exclusion is not read as an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values the parameters do not allow
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Query 'x' -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Query 'x' -Limit 1001
    } -MessageLike "*'Limit'*maximum allowed range of 1000*" -Message 'and so is one above 1000, which gh refuses'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Query 'x' -Match 'title'
    } -MessageLike "*'Match'*file,path*" -Message 'A field code cannot be matched on is refused, naming the ones it can'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Repository '' -Filename 'x.go'
    } -MessageLike '-Repository was given but is blank, so it would filter nothing*Give a value, or leave -Repository off.' `
        -Message 'An empty repository is refused, not dropped'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Owner @() -Filename 'x.go'
    } -MessageLike '-Owner was given but is empty*' -Message 'and so is an empty list of owners'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Owner 'a,b'
    } -MessageLike "-Owner value 'a,b' holds a comma*" `
        -Message 'An owner holding a comma is refused, as gh would split it'
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Limit 5
    } -MessageLike 'Give a query or at least one filter*' -Message 'No query and no filter is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh rejects the search
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Validation Failed (HTTP 422)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Find-GitHubCode -Query 'x'
    } -MessageLike '*Searching code failed*Validation Failed (HTTP 422)*' `
        -Message 'A failed search throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
