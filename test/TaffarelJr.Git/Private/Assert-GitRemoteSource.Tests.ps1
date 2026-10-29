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
$other = New-GitTestRepo
try {
    git -C $repo remote add origin 'https://example.invalid/o/r.git' 2>&1 | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo 'sibling') | Out-Null
    $check = {
        param($Name, $Repo)
        Assert-GitRemoteSource -Name $Name -Activity 'Testing' -RepoPath $Repo
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $remote = & $module $check 'origin' $repo
    $url = & $module $check 'https://example.invalid/x.git' $repo
    $scp = & $module $check 'git@example.invalid:o/r.git' $repo
    $absolute = & $module $check $other $repo
    $relative = & $module $check 'sibling' $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @($remote).Count -Message 'A configured remote passes, returning nothing'
    Assert-Equal -Expected 0 -Actual @($url).Count -Message 'so does a URL'
    Assert-Equal -Expected 0 -Actual @($scp).Count -Message 'and an scp-style address, which has a colon too'
    Assert-Equal -Expected 0 -Actual @($absolute).Count -Message 'and a full path that exists'
    Assert-Equal -Expected 0 -Actual @($relative).Count -Message 'and a path that exists relative to -RepoPath'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Push-Location -LiteralPath $repo

    # Act - no -RepoPath: a relative path is read against the current location
    try {
        $current = & $module { Assert-GitRemoteSource -Name 'sibling' -Activity 'Testing' }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @($current).Count -Message 'Without -RepoPath, the current location is the base'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { & $module $check 'nope' $repo } `
        -MessageLike "Testing failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message 'A name that is no remote, URL or path throws'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $other
}

exit (Complete-TestRun)
