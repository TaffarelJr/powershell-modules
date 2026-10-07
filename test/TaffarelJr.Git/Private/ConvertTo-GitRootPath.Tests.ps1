#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$rows = @(
    @{ Path = 'src\sub\x.txt'; Expected = 'src/sub/x.txt' }
    @{ Path = 'src/./x.txt'; Expected = 'src/x.txt' }
    @{ Path = 'src//sub/../x.txt/'; Expected = 'src/x.txt' }
    @{ Path = 'src/..'; Expected = '' }
)

# Act / Assert
foreach ($row in $rows) {
    $normalized = & $module { param($p) ConvertTo-GitRootPath -Activity 'Reading' -Path $p } $row.Path
    Assert-Equal -Expected $row.Expected -Actual $normalized -Message "'$($row.Path)' becomes '$($row.Expected)'"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { & $module { ConvertTo-GitRootPath -Activity 'Reading' -Path 'a/../..' } } `
    -MessageLike "Reading failed: -Path 'a/../..' climbs above the repository root.*" `
        -Message 'A path that climbs above the root throws'

exit (Complete-TestRun)
