#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One check across every function that returns something: the type its
# [OutputType()] declares is the type of what a real call returns. Each call is
# made against a throwaway repository, with a bare one beside it standing in
# for a remote, so nothing leaves the machine.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$origin = New-GitTestRepo
$bare = Join-Path ([System.IO.Path]::GetTempPath()) "git-bare-$([guid]::NewGuid())"
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-clone-$([guid]::NewGuid())"
$paused = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone of a bare copy, so it has a remote and an upstream, with one commit past a tag, a
    # rename, and a commit the remote lacks
    git clone --quiet --bare $origin $bare 2>&1 | Out-Null
    git clone --quiet $bare $clone 2>&1 | Out-Null
    git -C $clone config user.name 'Test' 2>&1 | Out-Null
    git -C $clone config user.email 'test@example.com' 2>&1 | Out-Null
    git -C $clone config core.autocrlf false 2>&1 | Out-Null
    git -C $clone tag v1.0.0 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $clone 'b.txt') -Value 'b' -NoNewline
    git -C $clone add -A 2>&1 | Out-Null
    git -C $clone commit --quiet -m 'add b' 2>&1 | Out-Null
    git -C $clone mv b.txt c.txt 2>&1 | Out-Null
    git -C $clone commit --quiet -m 'rename b' 2>&1 | Out-Null

    # Act - each function called once for real, the answers kept by function name
    $samples = [ordered]@{}
    $samples['Get-GitBranch'] = @(Get-GitBranch -RepoPath $clone)
    $samples['Compare-GitBranch'] = @(Compare-GitBranch -RepoPath $clone)
    $samples['Get-GitCherry'] = @(Get-GitCherry -Base 'v1.0.0' -Upstream 'main' -RepoPath $clone)
    $samples['Get-GitCommit'] = @(Get-GitCommit -RepoPath $clone)
    $samples['Get-GitConfig'] = @(Get-GitConfig -Name 'user.name' -RepoPath $clone)
    $samples['Get-GitDefaultBranch'] = @(Get-GitDefaultBranch -RepoPath $clone)
    $samples['Get-GitDiff'] = @(Get-GitDiff -FromRef 'v1.0.0' -ToRef 'HEAD' -RepoPath $clone)
    $samples['Get-GitDirectory'] = @(Get-GitDirectory -RepoPath $clone)
    $samples['Get-GitLog'] = @(Get-GitLog -RepoPath $clone)
    $samples['Get-GitMergeBase'] = @(Get-GitMergeBase -Ref1 'main' -Ref2 'v1.0.0' -RepoPath $clone)
    $samples['Get-GitRemote'] = @(Get-GitRemote -RepoPath $clone)
    $samples['Get-GitRename'] = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -RepoPath $clone)
    $samples['Get-GitRepositoryRoot'] = @(Get-GitRepositoryRoot -RepoPath $clone)
    $samples['Get-GitRootCommit'] = @(Get-GitRootCommit -RepoPath $clone)
    $samples['Get-GitTag'] = @(Get-GitTag -RepoPath $clone)
    $samples['Resolve-GitRef'] = @('main' | Resolve-GitRef -RepoPath $clone)
    $samples['Test-GitAncestor'] = @(Test-GitAncestor -Ancestor 'v1.0.0' -Descendant 'main' -RepoPath $clone)
    $samples['Test-GitChange'] = @(Test-GitChange -RepoPath $clone)
    $samples['Test-GitPath'] = @(Test-GitPath -Path 'c.txt' -RepoPath $clone)
    $samples['Test-GitRebaseInProgress'] = @(Test-GitRebaseInProgress -RepoPath $clone)
    $samples['Test-GitRepository'] = @(Test-GitRepository -RepoPath $clone)

    Set-Content -LiteralPath (Join-Path $clone 'a.txt') -Value 'changed' -NoNewline
    $samples['Get-GitStatus'] = @(Get-GitStatus -RepoPath $clone)
    $samples['Save-GitStash'] = @(Save-GitStash -Message 'work in progress' -RepoPath $clone)
    $samples['Get-GitStash'] = @(Get-GitStash -RepoPath $clone)
    $samples['Restore-GitStash'] = @(Restore-GitStash -RepoPath $clone)
    git -C $clone checkout --quiet -- a.txt 2>&1 | Out-Null
    git -C $clone branch side 'v1.0.0' 2>&1 | Out-Null
    $samples['Merge-GitBranch'] = @(Merge-GitBranch -Ref 'side' -RepoPath $clone)
    $samples['Start-GitRebase'] = @(Start-GitRebase -Ref 'v1.0.0' -RepoPath $clone)
    $samples['Push-GitCommit'] = @(Push-GitCommit -Force -RepoPath $clone)
    $samples['Update-GitBranch'] = @(Update-GitBranch -RepoPath $clone)

    git -C $paused checkout --quiet -b other 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $paused 'a.txt') -Value 'other' -NoNewline
    git -C $paused commit --quiet -am 'other' 2>&1 | Out-Null
    git -C $paused checkout --quiet main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $paused 'a.txt') -Value 'main' -NoNewline
    git -C $paused commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $paused checkout --quiet other 2>&1 | Out-Null
    $stopped = Start-GitRebase -Ref 'main' -RepoPath $paused
    $samples['Get-GitConflict'] = @(Get-GitConflict -RepoPath $paused)
    Set-Content -LiteralPath (Join-Path $paused 'a.txt') -Value 'fixed' -NoNewline
    Add-GitChange -RepoPath $paused
    $samples['Resume-GitRebase'] = @(Resume-GitRebase -RepoPath $paused)

    # Assert
    Assert-Equal -Expected $true -Actual $stopped.Conflict -Message 'Precondition: the rebase paused on a conflict'
    $object = @{ Declared = 'PSObject'; Actual = 'PSCustomObject' }
    $text = @{ Declared = 'String'; Actual = 'String' }
    $flag = @{ Declared = 'Boolean'; Actual = 'Boolean' }
    $expected = [ordered]@{
        'Get-GitBranch' = $text; 'Compare-GitBranch' = $object; 'Get-GitCherry' = $object; 'Get-GitCommit' = $object
        'Get-GitConfig' = $text; 'Get-GitConflict' = $text; 'Get-GitDefaultBranch' = $text; 'Get-GitDiff' = $text
        'Get-GitDirectory' = $text; 'Get-GitLog' = $object; 'Get-GitMergeBase' = $text; 'Get-GitRemote' = $text
        'Get-GitRename' = $object; 'Get-GitRepositoryRoot' = $text; 'Get-GitRootCommit' = $text
        'Get-GitStash' = $object; 'Get-GitStatus' = $object; 'Get-GitTag' = $text; 'Merge-GitBranch' = $object
        'Push-GitCommit' = $flag; 'Resolve-GitRef' = $text; 'Restore-GitStash' = $object
        'Resume-GitRebase' = $object; 'Save-GitStash' = $flag; 'Start-GitRebase' = $object
        'Test-GitAncestor' = $flag; 'Test-GitChange' = $flag; 'Test-GitPath' = $flag
        'Test-GitRebaseInProgress' = $flag; 'Test-GitRepository' = $flag; 'Update-GitBranch' = $object
    }

    foreach ($name in $expected.Keys) {
        $declaredTypes = @((Get-Command -Name $name).OutputType | ForEach-Object { $_.Type.Name })
        $actualTypes = @($samples[$name] | ForEach-Object { $_.GetType().Name } | Sort-Object -Unique)
        Assert-That -Condition ($samples[$name].Count -gt 0) -Message "$name returned something to compare"
        Assert-Equal -Expected @($expected[$name].Declared) -Actual $declaredTypes `
            -Message "$name declares the type it returns"
        Assert-Equal -Expected @($expected[$name].Actual) -Actual $actualTypes `
            -Message "$name returns objects of that type"
    }

    $missing = @(
        foreach ($command in Get-Command -Module TaffarelJr.Git) {
            if (@($command.OutputType).Count -gt 0 -and -not $expected.Contains($command.Name)) {
                $command.Name
            }
        }
    )
    Assert-Equal -Expected @() -Actual $missing `
        -Message 'No function declares an output type that this file does not check'
}
finally {
    foreach ($path in $origin, $bare, $clone, $paused) {
        Remove-GitTestRepo -Path $path
    }
}

exit (Complete-TestRun)
