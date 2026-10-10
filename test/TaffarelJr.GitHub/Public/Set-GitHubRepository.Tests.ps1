#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - plain value settings
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Description 'd' -Homepage 'https://h' -DefaultBranch 'main' -AddTopic @('ci', 'gh') -RemoveTopic @('old') -SquashMergeCommitMessage pr-title
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--description', 'd', '--homepage', 'https://h', '--default-branch', 'main', '--add-topic', 'ci', '--add-topic', 'gh', '--remove-topic', 'old', '--squash-merge-commit-message', 'pr-title') -Actual $call.Arguments -Message 'Each value setting becomes its gh flag, one --add-topic/--remove-topic per topic'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a toggle on, a toggle off, and the rest left alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -EnableWiki:$false -DeleteBranchOnMerge -Template
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'edit', '--enable-wiki=false', '--delete-branch-on-merge=true', '--template=true') -Actual $call.Arguments -Message 'A toggle given as $false turns off, one given turns on, and an omitted one is not mentioned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every remaining toggle
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -EnableIssues -EnableProjects -EnableDiscussions -EnableMergeCommit -EnableSquashMerge -EnableRebaseMerge -EnableAutoMerge -EnableAdvancedSecurity -EnableSecretScanning -EnableSecretScanningPushProtection -AllowForking -AllowUpdateBranch
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'edit', '--enable-issues=true', '--enable-projects=true', '--enable-discussions=true', '--enable-merge-commit=true', '--enable-squash-merge=true', '--enable-rebase-merge=true', '--enable-auto-merge=true', '--enable-advanced-security=true', '--enable-secret-scanning=true', '--enable-secret-scanning-push-protection=true', '--allow-forking=true', '--allow-update-branch=true') -Actual $call.Arguments -Message 'Every toggle maps to its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a visibility change
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Visibility private
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'edit', 'o/r', '--visibility', 'private', '--accept-visibility-change-consequences') -Actual $call.Arguments -Message 'Changing visibility carries the acknowledgement gh requires'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - archiving alone, nothing to edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r' -Archived
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the archive call is made'
    Assert-Equal -Expected @('repo', 'archive', 'o/r', '--yes') -Actual $calls[0].Arguments -Message '-Archived archives without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - unarchiving alongside an edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Description 'back' -Archived:$false
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and an archive change are two gh calls'
    Assert-Equal -Expected @('repo', 'edit', '--description', 'back') -Actual $calls[0].Arguments -Message 'The edit goes first'
    Assert-Equal -Expected @('repo', 'unarchive', '--yes') -Actual $calls[1].Arguments -Message '-Archived:$false unarchives without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing at all to change
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubRepository -Repository 'o/r'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'With no setting given, gh is not called at all'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
