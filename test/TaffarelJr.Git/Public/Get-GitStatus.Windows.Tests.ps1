#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the 260-character path limit is a Windows one')
}

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an untracked file whose full path is well over 260 characters
$repo = New-GitTestRepo
try {
    $segment = 'd' * 50
    $deep = Join-Path $repo $segment $segment $segment $segment $segment $segment
    [System.IO.Directory]::CreateDirectory($deep) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $deep 'long.txt'), 'x')
    $relative = (@($segment) * 6 + 'long.txt') -join '/'

    # Act
    $status = @(Get-GitStatus -RepoPath $repo)

    # Assert
    Assert-That -Condition ((Join-Path $deep 'long.txt').Length -gt 260) -Message 'Precondition: the path is a long one'
    Assert-Equal -Expected @("?? $relative") -Actual @($status | ForEach-Object { "$($_.Status) $($_.Path)" }) `
        -Message 'A file under a path over 260 characters is listed, not left out of a tree that reads as clean'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
