#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
try {
    git -C $repo tag v1 2>&1 | Out-Null
    $check = {
        param($Kind, $Name, $Repo, [switch]$MayExist)
        Assert-GitNameAvailable -Kind $Kind -Name $Name -Activity 'Testing' -MayExist:$MayExist -RepoPath $Repo
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $branch = & $module $check 'branch' 'feature/x' $repo
    $tag = & $module $check 'tag' 'v2' $repo
    $remote = & $module $check 'remote' 'upstream' $repo
    $existing = & $module $check 'branch' 'main' $repo -MayExist
    $otherKind = & $module $check 'tag' 'main' $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @($branch).Count `
        -Message 'A new, well-formed branch name passes, returning nothing'
    Assert-Equal -Expected 0 -Actual @($tag).Count -Message 'so does a new tag name'
    Assert-Equal -Expected 0 -Actual @($remote).Count -Message 'and a remote name'
    Assert-Equal -Expected 0 -Actual @($existing).Count -Message 'With -MayExist, a branch that exists passes'
    Assert-Equal -Expected 0 -Actual @($otherKind).Count `
        -Message 'A tag may take a name only a branch has: just a ref of its own kind counts'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { & $module $check 'branch' 'main' $repo } `
        -MessageLike "Testing failed: a branch named 'main' already exists." -Message 'A branch that exists throws'
    Assert-Throws -ScriptBlock { & $module $check 'tag' 'v1' $repo } `
        -MessageLike "Testing failed: a tag named 'v1' already exists." -Message 'so does a tag that exists'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - names git would refuse
    Assert-Throws -ScriptBlock { & $module $check 'branch' 'a..b' $repo -MayExist } `
        -MessageLike "Testing failed: 'a..b' is not a valid branch name." `
        -Message 'A malformed branch name throws, even with -MayExist'
    Assert-Throws -ScriptBlock { & $module $check 'tag' 'x.lock' $repo } `
        -MessageLike "Testing failed: 'x.lock' is not a valid tag name." -Message 'so does a malformed tag name'
    Assert-Throws -ScriptBlock { & $module $check 'remote' 'a b' $repo } `
        -MessageLike "Testing failed: 'a b' is not a valid remote name." -Message 'and a malformed remote name'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - HEAD, which check-ref-format allows under refs/heads
    Assert-Throws -ScriptBlock { & $module $check 'branch' 'HEAD' $repo -MayExist } `
        -MessageLike "Testing failed: 'HEAD' is not a valid branch name." `
        -Message 'HEAD is no branch name, even with -MayExist'

    # Act
    $headTag = & $module $check 'tag' 'HEAD' $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @($headTag).Count -Message 'while a tag may take it, as git allows'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - what to do instead, added to the message
    Assert-Throws -ScriptBlock {
        & $module {
            param($Repo)
            Assert-GitNameAvailable -Kind 'branch' -Name 'main' -Activity 'Testing' -Hint 'Do this.' -RepoPath $Repo
        } $repo
    } -MessageLike "Testing failed: a branch named 'main' already exists. Do this." `
        -Message '-Hint follows the message for a name that exists'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
