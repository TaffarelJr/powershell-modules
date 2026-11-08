#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# Only Windows runs a .cmd, and runs it through cmd.exe.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'a .cmd shim is run through cmd.exe on Windows only')
}

# Run from inside the sandbox, so a launch that cmd.exe misread could only
# ever redirect into it.
$sandbox = New-VSCodeSandbox
Push-Location -LiteralPath $sandbox.Root
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install with only its shim, and a folder named with an &
    $install = Add-FakeVSCodeShim -Fixture $sandbox
    $folder = Join-Path $sandbox.Root 'R&D'
    New-Item -ItemType Directory -Path $folder | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $folder
    } -MessageLike 'Could not launch VS Code: cmd.exe would misread*Code.exe*' `
        -Message 'A folder cmd.exe would cut in two is refused, pointing at Code.exe'

    #───────────────────────────────────────────────────────────────────────────
    # Act - give a launch that should not have happened the time to show
    $ran = Wait-TestFile -Path $install.Received -TimeoutSeconds 3

    # Assert
    Assert-That -Condition (-not $ran) -Message 'The shim never ran'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same install, with its shim a .bat file
    $batInstall = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code.bat'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $folder
    } -MessageLike 'Could not launch VS Code: cmd.exe would misread*Code.exe*' `
        -Message 'A folder cmd.exe would cut in two is refused for a .bat shim too'

    # Act
    $batRan = Wait-TestFile -Path $batInstall.Received -TimeoutSeconds 3

    # Assert
    Assert-That -Condition (-not $batRan) -Message 'and that shim never ran either'
}
finally {
    Pop-Location
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
