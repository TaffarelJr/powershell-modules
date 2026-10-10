#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new title and body, and a label swap
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12 -Title 'Renamed' -Body 'New body' -AddLabel @('needs fix') -RemoveLabel @('ready') -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'edit', '12', '--title', 'Renamed', '--body-file', '-', '--add-label', 'needs fix', '--remove-label', 'ready', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input; the rest become their gh flags'
    Assert-Equal -Expected 'New body' -Actual $call.StdIn -Message 'The body itself is what gets piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every remaining edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -Base 'develop' -Milestone 'v2' -RemoveMilestone -AddAssignee @('@me') -RemoveAssignee @('bob') -AddReviewer @('org/team', 'ann') -RemoveReviewer @('cat') -AddProject @('Roadmap') -RemoveProject @('Old')
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'edit', '--base', 'develop', '--milestone', 'v2', '--remove-milestone', '--add-assignee', '@me', '--remove-assignee', 'bob', '--add-reviewer', 'org/team', '--add-reviewer', 'ann', '--remove-reviewer', 'cat', '--add-project', 'Roadmap', '--remove-project', 'Old') -Actual $call.Arguments -Message 'Each edit becomes its gh flag, one per list element'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - marking ready alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12 -Ready
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the ready call is made'
    Assert-Equal -Expected @('pr', 'ready', '12') -Actual $calls[0].Arguments -Message '-Ready marks the pull request ready for review'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - back to a draft, alongside an edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -Title 'WIP' -Ready:$false
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and a draft-state change are two gh calls'
    Assert-Equal -Expected @('pr', 'edit', '--title', 'WIP') -Actual $calls[0].Arguments -Message 'The edit goes first'
    Assert-Equal -Expected @('pr', 'ready', '--undo') -Actual $calls[1].Arguments -Message '-Ready:$false converts the pull request to a draft'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing to change
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubPullRequest -PullRequest 12
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count -Message 'With no change given, gh is not called at all'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
