#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,defaultBranchRef,deleteBranchOnMerge,description,forkCount,hasDiscussionsEnabled,' +
'hasIssuesEnabled,hasProjectsEnabled,hasWikiEnabled,homepageUrl,isArchived,isEmpty,isFork,isPrivate,' +
'isTemplate,licenseInfo,mergeCommitAllowed,name,nameWithOwner,owner,parent,primaryLanguage,pushedAt,' +
'rebaseMergeAllowed,repositoryTopics,squashMergeAllowed,sshUrl,stargazerCount,updatedAt,url,visibility'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one named repository
$fake = New-FakeGitHubCli -Output @('{"nameWithOwner":"o/r","visibility":"PUBLIC","defaultBranchRef":{"name":"main"}}')
try {
    # Act
    $repository = Get-GitHubRepository -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'view', 'o/r', '--json', $fields) -Actual $call.Arguments `
        -Message 'The repository is passed positionally, as gh repo view takes it'
    Assert-Equal -Expected 'o/r' -Actual $repository.NameWithOwner `
        -Message 'The repository comes back as one object with PascalCase fields'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'view', '--json', $fields) -Actual $call.Arguments `
        -Message 'Without -Repository, gh is left to infer it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing an owner's repositories with every filter, the visibility in mixed case
$fake = New-FakeGitHubCli -Output @('[{"name":"a"},{"name":"b"}]')
try {
    # Act
    $repositories = Get-GitHubRepository -List -Owner 'TaffarelJr' -Limit 50 -Visibility 'Public' -Language PowerShell `
        -Topic @('ci', 'gh') `
        -Fork `
        -Archived
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'repo', 'list', 'TaffarelJr', '--json', $fields, '--limit', '50', '--visibility', 'public',
            '--language=PowerShell', '--topic=ci', '--topic=gh', '--fork', '--archived'
        ) `
        -Actual $call.Arguments `
        -Message 'Each list filter becomes its gh flag, the visibility lower-cased'
    Assert-Equal -Expected 2 -Actual $repositories.Count -Message 'Every listed repository is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only non-forks, archived ones left out
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubRepository -List -Source -Archived:$false | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'list', '--json', $fields, '--source', '--no-archived') -Actual $call.Arguments `
        -Message '-Source lists non-forks, and -Archived:$false leaves archived repositories out'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'list', '--json', $fields) -Actual $call.Arguments `
        -Message 'Without -Owner, gh lists the authenticated user''s repositories'
    Assert-That -Condition ($repositories -isnot [array]) `
        -Message 'A single listed repository is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that look like options, a limit that asks for nothing, filters that exclude each other, and no repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Owner '--limit'
    } -MessageLike "*'--limit' starts with '-', which gh would read as an option*" `
        -Message 'An owner starting with a dash is refused'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Fork -Source
    } -MessageLike '-Fork and -Source cannot be used together: -Fork lists only forks, and -Source only non-forks. Give only one.' `
        -Message '-Fork and -Source together are refused, as gh would refuse them'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of describing the current directory''s'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -Repository ''
    } -MessageLike '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.' -Message 'as does an empty one'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Language ''
    } -MessageLike '-Language was given but is blank, so it would filter nothing. Give a value, or leave -Language off.' `
        -Message 'A blank language is refused, not dropped to list every language'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Topic 'ci', ' '
    } -MessageLike '*-Topic holds a blank topic, which would filter nothing. Give a value, or leave -Topic off.' `
        -Message 'as is a blank topic'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Owner ''
    } -MessageLike '-Owner was given but is blank, so it would list your own repositories. Give a value, or leave -Owner off.' `
        -Message 'A blank owner is refused, not taken as the authenticated user'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Owner ' '
    } -MessageLike '-Owner was given but is blank*' -Message 'as is a whitespace one'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Topic @()
    } -MessageLike '-Topic was given no topics, so it would filter nothing. Give a value, or leave -Topic off.' `
        -Message 'An empty list of topics is refused, not dropped to list everything'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -List -Topic $null
    } -MessageLike '*-Topic holds a blank topic, which would filter nothing. Give a value, or leave -Topic off.' `
        -Message 'and $null gets the same sentence, not PowerShell''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh failing to read a named repository and the current one
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 404: Not Found') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository -Repository 'o/r'
    } -MessageLike 'Reading repository o/r failed*Not Found*' -Message 'A failure names the repository that was read'
    Assert-Throws -ScriptBlock {
        Get-GitHubRepository
    } -MessageLike 'Reading the current directory''s repository failed*Not Found*' `
        -Message 'or says it was the current directory''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
