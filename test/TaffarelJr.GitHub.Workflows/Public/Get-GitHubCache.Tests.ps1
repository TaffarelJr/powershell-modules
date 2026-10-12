#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"id":1,"key":"node-modules-abc","sizeInBytes":1024}]')
try {
    # Act
    $caches = Get-GitHubCache -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'Caches are asked for as JSON with a fixed field set'
    Assert-That -Condition ($caches -isnot [array]) `
        -Message 'A single cache is written as that one object, not wrapped in an array'
    Assert-Equal -Expected 1024 -Actual $caches.SizeInBytes -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every filter
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $caches = @(Get-GitHubCache -Key 'node-modules' -Ref 'refs/heads/main' -Sort Size_In_Bytes -Order ASC -Limit 10)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'cache', 'list', '--json', $fields, '--key=node-modules', '--ref=refs/heads/main'
        '--sort', 'size_in_bytes', '--order', 'asc', '--limit', '10'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag, with -Sort and -Order lower-cased as gh needs them'
    Assert-Equal -Expected 0 -Actual $caches.Count -Message 'No caches writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a key and a ref that look like timestamps
$json = '[{"id":1,"key":"2026-01-02T03:04:05Z","ref":"refs/heads/2026-01-02T03:04:05Z",' +
'"createdAt":"2026-01-02T03:04:05Z"}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $cache = Get-GitHubCache

    # Assert
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $cache.Key `
        -Message 'A key that looks like a timestamp stays the text it is'
    Assert-Equal -Expected 'refs/heads/2026-01-02T03:04:05Z' -Actual $cache.Ref -Message 'as does a ref'
    Assert-That -Condition ($cache.CreatedAt -is [datetime]) -Message 'while a real timestamp field is a [datetime]'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - caches listed with and without -Repository
$fake = New-FakeGitHubCli -Output @('[{"id":1,"key":"a"}]')
try {
    # Act
    $given = Get-GitHubCache -Repository ([PSCustomObject]@{ NameWithOwner = 'other/repo' })
    $current = Get-GitHubCache
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'list', '--json', $fields, '--repo', 'other/repo') -Actual $call.Arguments `
        -Message 'A repository object is read for its name'
    Assert-Equal -Expected 'other/repo' -Actual $given.Repository `
        -Message 'and each cache carries the repository it was read from'
    Assert-That -Condition ($null -ne $current.PSObject.Properties['Repository'] -and $null -eq $current.Repository) `
        -Message 'A cache listed from the current repository carries a $null Repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same repository named as a URL and as OWNER/REPO, and one on another host
$fake = New-FakeGitHubCli -Output @('[{"id":1,"key":"a"}]')
try {
    # Act
    $viaUrl = Get-GitHubCache -Repository 'https://github.com/o/r.git'
    $viaName = Get-GitHubCache -Repository 'o/r'
    $other = Get-GitHubCache -Repository 'https://x-access-token:SENTINEL@ghe.example.com/o/r'

    # Assert
    Assert-Equal -Expected @('o/r', 'o/r') -Actual @($viaUrl.Repository, $viaName.Repository) `
        -Message 'Where-Object Repository -EQ OWNER/REPO finds a cache however its repository was named'
    Assert-Equal -Expected 'ghe.example.com/o/r' -Actual $other.Repository `
        -Message 'A cache on another host carries HOST/OWNER/REPO, with no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - free text that gh could read as an option
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubCache -Key '--' -Ref '-x' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'list', '--json', $fields, '--key=--', '--ref=-x') -Actual $call.Arguments `
        -Message 'A key or ref is joined to its flag, so gh never reads it as an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that ask for nothing, and a repository given positionally
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubCache -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubCache -Key ''
    } -MessageLike '-Key was given but is blank, so it would filter nothing. Give a value, or leave -Key off.' `
        -Message 'A blank key is refused, not dropped to list every cache'
    Assert-Throws -ScriptBlock {
        Get-GitHubCache -Ref ' '
    } -MessageLike '-Ref was given but is blank, so it would filter nothing. Give a value, or leave -Ref off.' `
        -Message 'as is a blank ref'
    Assert-Throws -ScriptBlock {
        Get-GitHubCache -Repository $null
    } -MessageLike '-Repository was given, but it is $null - leave it out to use*' `
        -Message 'A -Repository given as $null is refused, not taken for the current directory''s'
    Assert-Throws -ScriptBlock {
        Get-GitHubCache 'o/r'
    } -MessageLike '*positional parameter cannot be found*' `
        -Message 'Nothing is positional, so a repository is not taken for a key'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
