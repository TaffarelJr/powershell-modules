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
# Arrange - no file at all: a command run from a prompt or -Command
$command = "Import-Module '$modulePath' -Force; `$m = Get-Module TaffarelJr.TestKit; '[' + (& `$m { Get-TestCaller }) + ']'"

# Act
$output = @(& pwsh -NoProfile -NonInteractive -Command $command)

# Assert
Assert-Equal -Expected '[]' -Actual $output[-1] -Message 'With no file in the call stack, there is no location to give'

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

# Act
$fromFrames = & $module { param($CallStack) Get-TestCaller -CallStack $CallStack } $frames
$fromKitOnly = & $module { param($CallStack) Get-TestCaller -CallStack $CallStack } $kitOnly

# Assert
Assert-Equal -Expected ' [Helper.ps1:3]' -Actual $fromFrames `
    -Message 'With no test file among the frames, the first file outside the kit is named'
Assert-Equal -Expected '' -Actual $fromKitOnly -Message 'With no file outside the kit, there is no location to give'

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

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a plain script, not a test file
    $plainFile = Join-Path $sandbox 'Plain.ps1'
    Set-Content -LiteralPath $plainFile -Value @(
        "Import-Module '$modulePath' -Force"
        "'[' + (& (Get-Module TaffarelJr.TestKit) { Get-TestCaller }) + ']'"
    )

    # Act
    $plainOutput = @(& pwsh -NoProfile -NonInteractive -File $plainFile)

    # Assert
    Assert-Equal -Expected '[ [Plain.ps1:2]]' -Actual $plainOutput[-1] `
        -Message 'With no test file in the call stack, the first file outside the kit is named'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a script in a folder whose name starts with the kit's own
    $kitCopy = Join-Path $sandbox 'TaffarelJr.TestKit'
    Copy-Item -LiteralPath (Split-Path -Parent $modulePath) -Destination $kitCopy -Recurse
    $siblingFolder = (New-Item -ItemType Directory -Path (Join-Path $sandbox 'TaffarelJr.TestKitExtras')).FullName
    $siblingFile = Join-Path $siblingFolder 'Sibling.ps1'
    Set-Content -LiteralPath $siblingFile -Value @(
        "Import-Module '$(Join-Path $kitCopy 'TaffarelJr.TestKit.psd1')' -Force"
        "'[' + (& (Get-Module TaffarelJr.TestKit) { Get-TestCaller }) + ']'"
    )

    # Act
    $siblingOutput = @(& pwsh -NoProfile -NonInteractive -File $siblingFile)

    # Assert
    Assert-Equal -Expected '[ [Sibling.ps1:2]]' -Actual $siblingOutput[-1] `
        -Message 'A folder that only starts with the kit''s folder name is not the kit'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
