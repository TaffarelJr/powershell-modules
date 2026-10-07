#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second commit with a multi-paragraph body
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second commit' -m 'A body explaining why.' 2>&1 | Out-Null
    $second = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - the default order is newest first
    $log = Get-GitLog -RepoPath $repo
    Assert-Equal -Expected 2 -Actual $log.Count -Message 'Every commit is returned'
    Assert-Equal -Expected $second -Actual $log[0].Hash -Message 'Newest first by default'
    Assert-Equal -Expected 'second commit' -Actual $log[0].Subject -Message 'Subject is parsed correctly'
    Assert-Equal -Expected 'A body explaining why.' -Actual $log[0].Body -Message 'Body is parsed correctly'
    Assert-Equal -Expected 'Test' -Actual $log[0].Author -Message 'Author is parsed correctly'
    Assert-Equal -Expected 'test@example.com' -Actual $log[0].Email -Message 'Email is parsed correctly'
    Assert-Equal -Expected 'initial' -Actual $log[1].Subject -Message 'The earlier commit comes second'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Reverse returns oldest first
    $reversed = Get-GitLog -Reverse -RepoPath $repo
    Assert-Equal -Expected 'initial' -Actual $reversed[0].Subject -Message '-Reverse puts the oldest commit first'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Count limits the result
    $limited = Get-GitLog -Count 1 -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $limited.Count -Message '-Count limits how many commits come back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a third commit touching a different file
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'third commit' 2>&1 | Out-Null

    # Act / Assert - -Path scopes the log to commits touching that file
    $scoped = Get-GitLog -Path 'b.txt' -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $scoped.Count -Message '-Path only returns commits touching that path'
    Assert-Equal -Expected 'second commit' -Actual $scoped[0].Subject -Message 'The right commit is returned'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
