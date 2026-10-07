#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
try {
    $expected = @("Reading the current branch: git -c core.longpaths=true -C $repo symbolic-ref --quiet HEAD")

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $own = @(Get-VerboseLine { Get-GitBranch -RepoPath $repo -Verbose })

    # Assert
    Assert-Equal -Expected $expected -Actual $own -Message 'A reader''s own -Verbose prints the git command line'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $wrapped = @(Get-VerboseLine { Invoke-VerboseCaller { Get-GitBranch -RepoPath $repo } })

    # Assert
    Assert-Equal -Expected $expected -Actual $wrapped `
        -Message 'and so does a $VerbosePreference its caller set in its own scope'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $quiet = @(Get-VerboseLine {
            Invoke-VerboseCaller { Get-GitBranch -RepoPath $repo -Verbose:$false }
        })

    # Assert
    Assert-Equal -Expected @() -Actual $quiet -Message 'while -Verbose:$false prints nothing, whatever the caller set'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
