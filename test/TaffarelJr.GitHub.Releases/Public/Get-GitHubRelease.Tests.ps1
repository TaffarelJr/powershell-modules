#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$viewFields = 'apiUrl,assets,author,body,createdAt,databaseId,id,isDraft,isImmutable,isPrerelease,name,' +
'publishedAt,tagName,tarballUrl,targetCommitish,uploadUrl,url,zipballUrl'
$listFields = 'createdAt,isDraft,isImmutable,isLatest,isPrerelease,name,publishedAt,tagName'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one release by tag
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1.0.0","isDraft":true,"assets":[{"name":"a.zip"}]}')
try {
    # Act
    $release = Get-GitHubRelease -Tag 'v1.0.0' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--repo', 'o/r', '--', 'v1.0.0') `
        -Actual $call.Arguments `
        -Message 'The full field set is asked for, and the tag comes last, after a --'
    Assert-Equal `
        -Expected 'v1.0.0' `
        -Actual $release.TagName `
        -Message 'The release comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'a.zip' -Actual $release.Assets[0].Name -Message 'Assets are re-cased too'
    Assert-Equal `
        -Expected 'o/r' `
        -Actual $release.Repository `
        -Message 'The -Repository it was read from is attached as Repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the latest release of the current repository
$fake = New-FakeGitHubCli -Output @('{"tagName":"v2","url":"https://github.com/a/b/releases/tag/v2"}')
try {
    # Act
    $release = Get-GitHubRelease
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields) `
        -Actual $call.Arguments `
        -Message 'Without -Tag, gh describes the latest release'
    Assert-Equal `
        -Expected 'a/b' `
        -Actual $release.Repository `
        -Message 'The repository is read from the release''s Url when -Repository is left out, as OWNER/REPO'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same repository named by a URL, by OWNER/REPO, and by the release's Url
$origins = @(
    @{
        Call    = { Get-GitHubRelease -Tag 'v1' -Repository 'https://github.com/o/r.git' }
        Message = 'A -Repository given as a URL is attached as OWNER/REPO'
    }
    @{
        Call    = { Get-GitHubRelease -Tag 'v1' -Repository 'o/r' }
        Message = 'as is one given as OWNER/REPO'
    }
    @{
        Call    = { Get-GitHubRelease -Tag 'v1' }
        Message = 'as is the one read from the release''s Url, so Where-Object Repository -eq finds them all'
    }
)
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1","url":"https://github.com/o/r/releases/tag/v1"}')
try {
    # Act / Assert
    foreach ($origin in $origins) {
        Assert-Equal -Expected 'o/r' -Actual (& $origin.Call).Repository -Message $origin.Message
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release on another host, from its Url and from a -Repository URL with a credential
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1","url":"https://ghe.example.com/o/r/releases/tag/v1"}')
try {
    # Act
    $fromUrl = Get-GitHubRelease -Tag 'v1'
    $fromGiven = Get-GitHubRelease -Tag 'v1' -Repository 'https://x-access-token:SENTINEL@ghe.example.com/o/r'

    # Assert
    Assert-Equal `
        -Expected 'ghe.example.com/o/r' `
        -Actual $fromUrl.Repository `
        -Message 'The Repository of an Enterprise release is HOST/OWNER/REPO'
    Assert-Equal `
        -Expected 'ghe.example.com/o/r' `
        -Actual $fromGiven.Repository `
        -Message 'and a given URL is shown the same way, with no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release given as a list of one, as @(Get-GitHubRelease ...) gives
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    $release = [PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }
    Get-GitHubRelease -Tag @($release) | Out-Null
    Get-GitHubRelease -Tag @('v2') | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--repo', 'a/b', '--', 'v1') `
        -Actual $calls[0].Arguments `
        -Message 'A list of one release is that release, read from the repository it came from'
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--', 'v2') `
        -Actual $calls[1].Arguments `
        -Message 'and a list of one tag is that tag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - chosen fields that leave out the Url
$fake = New-FakeGitHubCli -Output @('{"tagName":"v2"}')
try {
    # Act
    $release = Get-GitHubRelease -Property 'tagName'

    # Assert
    Assert-Equal `
        -Expected @('TagName', 'Repository') `
        -Actual @($release.PSObject.Properties.Name) `
        -Message 'With no Url and no -Repository, Repository is still attached'
    Assert-Equal `
        -Expected $null `
        -Actual $release.Repository `
        -Message 'as $null, for the current directory''s repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a tag that looks like an option
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    Get-GitHubRelease -Tag '--web' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--', '--web') `
        -Actual $call.Arguments `
        -Message 'A tag is an operand whatever it starts with'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - fields named as the result spells them, padded, and comma-joined
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    Get-GitHubRelease -Tag 'v1' -Property 'TagName', ' isDraft , ', 'Url' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', 'tagName,isDraft,url', '--', 'v1') `
        -Actual $call.Arguments `
        -Message '-Property replaces the default fields, spelled as gh spells them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one chosen field, for one release and for a listing
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = @('{"name":"One","tagName":"v1","url":"https://github.com/o/r/releases/tag/v1"}') }
    @{ Output = @('[{"name":"One","tagName":"v1"}]') }
)
try {
    # Act
    Get-GitHubRelease -Tag 'v1' -Property 'name' -Repository 'o/r' | Out-Null
    Get-GitHubRelease -List -Property 'name' -Repository 'o/r' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', 'name,tagName,url', '--repo', 'o/r', '--', 'v1') `
        -Actual $calls[0].Arguments `
        -Message 'tagName and url are always added, so the release can be piped on'
    Assert-Equal `
        -Expected @('release', 'list', '--json', 'name,tagName', '--repo', 'o/r') `
        -Actual $calls[1].Arguments `
        -Message 'and tagName to a listing, which gh offers no url for'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing of one chosen field, piped on
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = @('[{"name":"One","tagName":"v1"}]') }
    @{ Output = @() }
)
try {
    # Act
    Get-GitHubRelease -List -Property 'name' -Repository 'o/r' | Remove-GitHubRelease
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'delete', '--yes', '--repo', 'o/r', '--', 'v1') `
        -Actual $calls[1].Arguments `
        -Message 'A listing of chosen fields still pipes on to the release in its repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - calls that are refused before gh
$refusals = @(
    @{
        Call    = { Get-GitHubRelease -Property ' , ' }
        Like    = '-Property names no field*'
        Message = 'An empty field list is refused, not sent as an unknown field'
    }
    @{
        Call    = { Get-GitHubRelease -Tag '' }
        Like    = "'' is not a release tag*"
        Message = 'An empty -Tag is refused, not taken for the latest release'
    }
    @{
        Call    = { Get-GitHubRelease -Tag $null }
        Like    = 'A release was given, but it is $null*'
        Message = 'as is a $null one'
    }
    @{
        Call    = { Get-GitHubRelease -List -Repository $null }
        Like    = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'A -Repository given as $null is refused, not taken for the current one'
    }
    @{
        Call    = { Get-GitHubRelease -Tag 'v1', 'v2' }
        Like    = 'Give one release at a time, not a list of 2; pipe them to name several.'
        Message = 'Several tags in one argument are refused, with advice to pipe them'
    }
    @{
        Call    = { Get-GitHubRelease -List -Limit 0 }
        Like    = "*'Limit'*minimum allowed range of 1*"
        Message = 'A limit below 1 is refused, not taken for gh''s default'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($refusal in $refusals) {
        Assert-Throws -ScriptBlock $refusal.Call -MessageLike $refusal.Like -Message $refusal.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - releases piped in as a listing returns them, one with a number for a tag
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    $listed = @([PSCustomObject]@{ TagName = 'v1'; Name = 'One' }, [PSCustomObject]@{ TagName = 2 })
    $listed | Get-GitHubRelease | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped release is described in its own call'
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--', '2') `
        -Actual $calls[1].Arguments `
        -Message 'The TagName is read from the piped object, a number included'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - tags piped in as text
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    @('v1', 'v2') | Get-GitHubRelease | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--', 'v2') `
        -Actual $calls[1].Arguments `
        -Message 'A tag piped in as text is described'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release listed from another repository, piped back in
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    [PSCustomObject]@{ TagName = 'v1'; Repository = 'other/repo' } | Get-GitHubRelease | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--repo', 'other/repo', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'The release is read from the repository it came from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from another repository given as -Tag, not piped
$fake = New-FakeGitHubCli -Output @('{"tagName":"x"}')
try {
    # Act
    Get-GitHubRelease -Tag ([PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }) | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'view', '--json', $viewFields, '--repo', 'a/b', '--', 'v1') `
        -Actual $call.Arguments `
        -Message 'A release given by name is read from the repository it came from too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter, the order in another casing
$fake = New-FakeGitHubCli -Output @('[{"tagName":"v2","isDraft":false},{"tagName":"v1","isDraft":true}]')
try {
    # Act
    $releases = Get-GitHubRelease -List -Limit 5 -ExcludeDrafts -ExcludePreReleases -Order ASC -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'release', 'list', '--json', $listFields, '--limit', '5', '--exclude-drafts', '--exclude-pre-releases',
        '--order', 'asc', '--repo', 'o/r'
    )
    Assert-Equal `
        -Expected $expected `
        -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag, the order lower-cased'
    Assert-Equal -Expected 2 -Actual $releases.Count -Message 'Every listed release is returned'
    Assert-Equal -Expected $true -Actual $releases[1].IsDraft -Message 'List fields are PascalCase'
    Assert-Equal `
        -Expected @('o/r', 'o/r') `
        -Actual @($releases.ForEach('Repository')) `
        -Message 'and each listed release carries the repository it was listed from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing of chosen fields, in the current repository
$fake = New-FakeGitHubCli -Output @('[{"tagName":"v1"}]')
try {
    # Act
    $releases = Get-GitHubRelease -List -Property 'TagName'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('release', 'list', '--json', 'tagName') `
        -Actual $call.Arguments `
        -Message '-Property applies to a listing too'
    Assert-That `
        -Condition ($releases -isnot [array]) `
        -Message 'A single listed release is written as that one object, not wrapped in an array'
    Assert-Equal `
        -Expected @('TagName', 'Repository') `
        -Actual @($releases.PSObject.Properties.Name) `
        -Message 'A listing gh gives no URL for, without -Repository, still carries Repository'
    Assert-Equal `
        -Expected $null `
        -Actual $releases.Repository `
        -Message 'as $null, for the current directory''s repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
