#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a title and body, plus a label swap
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Title 'Renamed' -Body 'New body' -AddLabel @('needs fix') -RemoveLabel @('ready') -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'edit', '12', '--title', 'Renamed', '--body-file', '-', '--add-label', 'needs fix', '--remove-label', 'ready', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input; the rest become their gh flags'
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
    Set-GitHubIssue -Issue 12 -Milestone 'v2' -RemoveMilestone -Type 'Bug' -RemoveType -Parent 5 -RemoveParent -AddAssignee @('@me') -RemoveAssignee @('bob') -AddProject @('Roadmap') -RemoveProject @('Old') -AddSubIssue @(6) -RemoveSubIssue @(7) -AddBlockedBy @(1) -RemoveBlockedBy @(2) -AddBlocking @(3) -RemoveBlocking @(4)
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'edit', '12', '--milestone', 'v2', '--remove-milestone', '--type', 'Bug', '--remove-type', '--parent', '5', '--remove-parent', '--add-assignee', '@me', '--remove-assignee', 'bob', '--add-project', 'Roadmap', '--remove-project', 'Old', '--add-sub-issue', '6', '--remove-sub-issue', '7', '--add-blocked-by', '1', '--remove-blocked-by', '2', '--add-blocking', '3', '--remove-blocking', '4') -Actual $call.Arguments -Message 'Each edit becomes its gh flag, in declared order'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pinning alone
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Pinned
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'With nothing to edit, only the pin call is made'
    Assert-Equal -Expected @('issue', 'pin', '12') -Actual $calls[0].Arguments -Message '-Pinned pins the issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - unpinning alongside an edit
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubIssue -Issue 12 -Title 'Unpinned' -Pinned:$false
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'An edit and a pin change are two gh calls'
    Assert-Equal -Expected @('issue', 'edit', '12', '--title', 'Unpinned') -Actual $calls[0].Arguments -Message 'The edit goes first'
    Assert-Equal -Expected @('issue', 'unpin', '12') -Actual $calls[1].Arguments -Message '-Pinned:$false unpins the issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the issue piped in by Number, nothing to change
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Number = 9 } | Set-GitHubIssue -Title 'x'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'edit', '9', '--title', 'x') -Actual $call.Arguments -Message 'The Number property binds from the pipeline as -Issue'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
