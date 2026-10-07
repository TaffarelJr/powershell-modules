#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A -RepoPath left out means the current folder, so one given but blank - a
# variable that was never set - must not silently mean the same. The commands
# are found by reflection, so one added later that forgets the guard fails here.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every command that takes -RepoPath
$commands = @(Get-Command -Module TaffarelJr.Git | Where-Object { $_.Parameters.ContainsKey('RepoPath') })
$patternType = [System.Management.Automation.ValidatePatternAttribute]

# Act
$unguarded = @(
    foreach ($command in $commands) {
        $guard = @($command.Parameters['RepoPath'].Attributes |
                Where-Object { $_ -is $patternType -and $_.RegexPattern -ceq '\S' })
        if ($guard.Count -eq 0) {
            $command.Name
        }
    }
)

# Assert
Assert-That -Condition ($commands.Count -gt 40) -Message 'Precondition: the commands with -RepoPath were found'
Assert-Equal -Expected '' -Actual ($unguarded -join ', ') -Message 'Every -RepoPath refuses a blank value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository as the current location, which a blank -RepoPath would
# have meant
$repo = New-GitTestRepo
try {
    $before = Get-GitTestRepoState -Repo $repo
    $blanks = @(
        @{ Value = $null; Shown = '$null' }
        @{ Value = ''; Shown = "''" }
        @{ Value = ' '; Shown = "' '" }
    )
    $refused = "Cannot validate argument on parameter 'RepoPath'. -RepoPath is blank:*"
    Push-Location -LiteralPath $repo

    # Act / Assert
    try {
        foreach ($blank in $blanks) {
            Assert-Throws -ScriptBlock { Get-GitStatus -RepoPath $blank.Value } -MessageLike $refused `
                -Message "A reader refuses -RepoPath $($blank.Shown)"
            Assert-Throws -ScriptBlock { New-GitBranch -Name 'made' -RepoPath $blank.Value } -MessageLike $refused `
                -Message "and so does a command that changes something, for -RepoPath $($blank.Shown)"
        }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message 'and nothing was made in the current folder'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository as the current location, with -RepoPath left out of
# commands that call others of the module on the way
$repo = New-GitTestRepo
try {
    $head = (git -C $repo rev-parse HEAD).Trim()
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'stashed' -NoNewline
    Push-Location -LiteralPath $repo

    # Act
    try {
        $commit = Get-GitCommit
        $root = Get-GitRootCommit
        $rebasing = Test-GitRebaseInProgress
        $saved = Save-GitStash
        $restored = Restore-GitStash
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $head -Actual $commit.Hash -Message 'Get-GitCommit reads the current folder'
    Assert-Equal -Expected $head -Actual $root -Message 'Get-GitRootCommit reads the current folder'
    Assert-Equal -Expected $false -Actual $rebasing -Message 'Test-GitRebaseInProgress reads the current folder'
    Assert-Equal -Expected $true -Actual $saved -Message 'Save-GitStash stashes in the current folder'
    Assert-Equal -Expected $false -Actual $restored.Conflict -Message 'and Restore-GitStash restores it there'
    Assert-Equal -Expected 'stashed' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'with the edit back in place'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
