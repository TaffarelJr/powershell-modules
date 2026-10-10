#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$viewFields = 'apiUrl,assets,author,body,createdAt,databaseId,id,isDraft,isImmutable,isPrerelease,name,publishedAt,tagName,tarballUrl,targetCommitish,uploadUrl,url,zipballUrl'
$listFields = 'createdAt,isDraft,isImmutable,isLatest,isPrerelease,name,publishedAt,tagName'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one release by tag
$fake = New-FakeGitHubCli -Output @('{"tagName":"v1.0.0","isDraft":true,"assets":[{"name":"a.zip"}]}')
try {
    # Act
    $release = Get-GitHubRelease -Tag 'v1.0.0' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'view', 'v1.0.0', '--json', $viewFields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The tag is positional and the full field set is asked for'
    Assert-Equal -Expected 'v1.0.0' -Actual $release.TagName -Message 'The release comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'a.zip' -Actual $release.Assets[0].Name -Message 'Assets are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the latest release
$fake = New-FakeGitHubCli -Output @('{"tagName":"v2"}')
try {
    # Act
    Get-GitHubRelease | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'view', '--json', $viewFields) -Actual $call.Arguments -Message 'Without -Tag, gh describes the latest release'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter
$fake = New-FakeGitHubCli -Output @('[{"tagName":"v2","isDraft":false},{"tagName":"v1","isDraft":true}]')
try {
    # Act
    $releases = Get-GitHubRelease -List -Limit 5 -ExcludeDrafts -ExcludePreReleases -Order asc -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'list', '--json', $listFields, '--limit', '5', '--exclude-drafts', '--exclude-pre-releases', '--order', 'asc', '--repo', 'o/r') -Actual $call.Arguments -Message 'Each filter becomes its gh flag'
    Assert-Equal -Expected 2 -Actual $releases.Count -Message 'Every listed release is returned'
    Assert-Equal -Expected $true -Actual $releases[1].IsDraft -Message 'List fields are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single listed release
$fake = New-FakeGitHubCli -Output @('[{"tagName":"v1"}]')
try {
    # Act
    $releases = Get-GitHubRelease -List

    # Assert
    Assert-That -Condition ($releases -is [array]) -Message 'A single listed release is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
