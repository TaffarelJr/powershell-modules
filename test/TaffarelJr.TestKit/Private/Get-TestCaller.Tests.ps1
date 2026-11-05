#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
$module = Get-Module TaffarelJr.TestKit

#───────────────────────────────────────────────────────────────────────────────
# Act
$caller = & $module { Get-TestCaller }

# Assert
Assert-That -Condition ($caller -match '^ \[Get-TestCaller\.Tests\.ps1:\d+\]$') `
    -Message 'The caller is the test file and line that made the call, not the kit'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - frames with no test file among them
$kitFolder = $module.ModuleBase
$elsewhere = [Path]::GetTempPath()
$frames = @(
    [PSCustomObject]@{ ScriptName = (Join-Path $kitFolder 'Public/Assert-That.ps1'); ScriptLineNumber = 5 }
    [PSCustomObject]@{ ScriptName = $null; ScriptLineNumber = 0 }
    [PSCustomObject]@{ ScriptName = (Join-Path $elsewhere 'Helper.ps1'); ScriptLineNumber = 3 }
    [PSCustomObject]@{ ScriptName = (Join-Path $elsewhere 'Runner.ps1'); ScriptLineNumber = 9 }
)
$kitOnly = @($frames[0], $frames[1])
$sibling = @([PSCustomObject]@{ ScriptName = (Join-Path ($kitFolder + 'Extras') 'Sibling.ps1'); ScriptLineNumber = 2 })

# Act
$fromFrames = & $module { param($CallStack) Get-TestCaller -CallStack $CallStack } $frames
$fromKitOnly = & $module { param($CallStack) Get-TestCaller -CallStack $CallStack } $kitOnly
$fromSibling = & $module { param($CallStack) Get-TestCaller -CallStack $CallStack } $sibling

# Assert
Assert-Equal -Expected ' [Helper.ps1:3]' -Actual $fromFrames `
    -Message 'With no test file among the frames, the first file outside the kit is named'
Assert-Equal -Expected '' -Actual $fromKitOnly -Message 'With no file outside the kit, there is no location to give'
Assert-Equal -Expected ' [Sibling.ps1:2]' -Actual $fromSibling `
    -Message 'A folder whose name only starts with the kit''s folder name is not the kit'

$sandbox = (New-Item -ItemType Directory -Path (Join-Path ([Path]::GetTempPath()) "caller-$([Guid]::NewGuid())")).FullName
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an assertion made inside a shared helper file
    $helperFile = Join-Path $sandbox 'SharedTestHelper.ps1'
    Set-Content -LiteralPath $helperFile `
        -Value 'function Get-CallerFromHelper { & (Get-Module TaffarelJr.TestKit) { Get-TestCaller } }'
    . $helperFile

    # Act
    $fromHelper = Get-CallerFromHelper
    $line = (Get-PSCallStack)[0].ScriptLineNumber

    # Assert
    Assert-Equal -Expected " [Get-TestCaller.Tests.ps1:$($line - 1)]" -Actual $fromHelper `
        -Message 'A call made through a helper file names the test file''s line, not the helper''s'

}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
