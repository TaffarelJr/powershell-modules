#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,defaultBranchRef,deleteBranchOnMerge,description,forkCount,hasDiscussionsEnabled,hasIssuesEnabled,hasProjectsEnabled,hasWikiEnabled,homepageUrl,isArchived,isEmpty,isFork,isPrivate,isTemplate,licenseInfo,mergeCommitAllowed,name,nameWithOwner,owner,parent,primaryLanguage,pushedAt,rebaseMergeAllowed,repositoryTopics,squashMergeAllowed,sshUrl,stargazerCount,updatedAt,url,visibility'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one named repository
$fake = New-FakeGitHubCli -Output @('{"nameWithOwner":"o/r","visibility":"PUBLIC","defaultBranchRef":{"name":"main"}}')
try {
    # Act
    $repository = Get-GitHubRepository -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'view', 'o/r', '--json', $fields) -Actual $call.Arguments -Message 'The repository is passed positionally, as gh repo view takes it'
    Assert-Equal -Expected 'o/r' -Actual $repository.NameWithOwner -Message 'The repository comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'main' -Actual $repository.DefaultBranchRef.Name -Message 'Nested objects are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository
$fake = New-FakeGitHubCli -Output @('{"name":"here"}')
try {
    # Act
    Get-GitHubRepository | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'view', '--json', $fields) -Actual $call.Arguments -Message 'Without -Repository, gh is left to infer it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing an owner's repositories with every filter
$fake = New-FakeGitHubCli -Output @('[{"name":"a"},{"name":"b"}]')
try {
    # Act
    $repositories = Get-GitHubRepository -List -Owner 'TaffarelJr' -Limit 50 -Visibility public -Language PowerShell -Topic @('ci', 'gh') -Fork -Source -Archived -NoArchived
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'list', 'TaffarelJr', '--json', $fields, '--limit', '50', '--visibility', 'public', '--language', 'PowerShell', '--topic', 'ci', '--topic', 'gh', '--fork', '--source', '--archived', '--no-archived') -Actual $call.Arguments -Message 'Each list filter becomes its gh flag'
    Assert-Equal -Expected 2 -Actual $repositories.Count -Message 'Every listed repository is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing the authenticated user's own, one result
$fake = New-FakeGitHubCli -Output @('[{"name":"only"}]')
try {
    # Act
    $repositories = Get-GitHubRepository -List
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'list', '--json', $fields) -Actual $call.Arguments -Message 'Without -Owner, gh lists the authenticated user''s repositories'
    Assert-That -Condition ($repositories -is [array]) -Message 'A single listed repository is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
