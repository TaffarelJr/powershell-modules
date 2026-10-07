#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One check across every function in the module, rather than one per function:
# a ref, branch, remote, URL or name is handed to git as a bare argument, and
# one that starts with a dash is read by git as an option - '--output=<file>'
# makes git log write a file, '--upload-pack=<command>' makes git clone run a
# command - while a blank one would silently mean the default. The parameters
# are found by reflection, so a function added later that forgets the guard
# fails here.

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
# Arrange - the parameters that carry something git reads as a name or revision,
# and every command in the module
$operandNames = 'Ref', 'Ref1', 'Ref2', 'FromRef', 'ToRef', 'Range', 'Branch', 'Upstream', 'Base',
'Ancestor', 'Descendant', 'Name', 'Remote', 'Url', 'StartPoint', 'Refspec', 'Pattern'
$commands = @(Get-Command -Module TaffarelJr.Git)
$patternType = [System.Management.Automation.ValidatePatternAttribute]

# Act
$checked = [System.Collections.Generic.List[string]]::new()
$unguarded = [System.Collections.Generic.List[string]]::new()
foreach ($command in $commands) {
    foreach ($name in $operandNames) {
        if (-not $command.Parameters.ContainsKey($name)) {
            continue
        }

        $guard = @($command.Parameters[$name].Attributes |
                Where-Object { $_ -is $patternType -and $_.RegexPattern -ceq '^(?!-)\S' })
        $checked.Add("$($command.Name) -$name")
        if ($guard.Count -eq 0) {
            $unguarded.Add("$($command.Name) -$name")
        }
    }
}

# Assert
Assert-That -Condition ($commands.Count -gt 0) -Message 'Precondition: the module''s commands were found'
Assert-That -Condition ($checked -contains 'Copy-GitRepository -Url') `
    -Message 'Precondition: the check reaches the clone URL'
Assert-That -Condition ($checked -contains 'Get-GitLog -Range') `
    -Message 'Precondition: the check reaches a revision range'
Assert-Equal -Expected '' -Actual ($unguarded -join ', ') `
    -Message 'Every ref, name, remote and URL parameter refuses a blank value and one that starts with a dash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the guard's own message, from one function
$thrown = $null
try {
    Get-GitCommit -Ref '--all'
}
catch {
    $thrown = $_
}

# Assert
Assert-That -Condition ($null -ne $thrown) -Message 'A value starting with a dash is refused'
Assert-That `
    -Condition ($thrown.Exception.Message -like "*'--all' is blank or starts with '-', which git reads as an option*") `
    -Message 'with a message that says why'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the guard's pattern, from one function
$parameter = (Get-Command Get-GitCommit).Parameters['Ref']
$pattern = ($parameter.Attributes | Where-Object { $_ -is $patternType }).RegexPattern

# Act / Assert - a value with a dash anywhere but the start is fine
foreach ($value in 'feature-x', 'release/1.0-rc', 'a-b-c', 'HEAD~1') {
    Assert-That -Condition ($value -match $pattern) -Message "'$value' passes the guard"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - and a blank one is not
foreach ($value in '', ' ', "`t") {
    Assert-That -Condition ($value -notmatch $pattern) -Message "'$value' does not pass the guard"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository with an uncommitted edit, which a hard reset to HEAD
# would discard, and a branch a force push to the current one would replace
$repo = New-GitTestRepo
$remote = Join-Path ([System.IO.Path]::GetTempPath()) "git-remote-$([Guid]::NewGuid()).git"
try {
    git init --quiet --bare $remote 2>&1 | Out-Null
    git -C $repo remote add origin $remote 2>&1 | Out-Null
    git -C $repo push --quiet origin main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'uncommitted' -NoNewline
    $before = Get-GitTestRepoState -Repo $repo
    $remoteBefore = git -C $remote rev-parse main
    $rows = @(
        @{ Call = { param($Value) Reset-GitBranch -Ref $Value -Mode Hard -RepoPath $repo }; Name = 'Ref' }
        @{ Call = { param($Value) Push-GitCommit -Branch $Value -Force -RepoPath $repo }; Name = 'Branch' }
        @{ Call = { param($Value) Get-GitLog -Range $Value -RepoPath $repo }; Name = 'Range' }
    )
    $blanks = @(
        @{ Value = $null; Shown = '$null' }
        @{ Value = ''; Shown = "''" }
        @{ Value = ' '; Shown = "' '" }
    )

    # Act / Assert
    foreach ($row in $rows) {
        foreach ($blank in $blanks) {
            Assert-Throws -ScriptBlock { & $row.Call $blank.Value } `
                -MessageLike "Cannot validate argument on parameter '$($row.Name)'. * is blank or starts with '-'*" `
                -Message "-$($row.Name) $($blank.Shown) is refused rather than read as the default"
        }
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message 'and nothing was reset: the uncommitted edit is still there'
    Assert-Equal -Expected $remoteBefore -Actual (git -C $remote rev-parse main) `
        -Message 'and nothing was pushed'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $remote
}

exit (Complete-TestRun)
