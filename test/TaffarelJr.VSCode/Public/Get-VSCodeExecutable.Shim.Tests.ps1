#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# The CLI shim is a code.cmd, found through PATHEXT - a shape only Windows has.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the CLI shim is a Windows .cmd')
}

$stable = @(Get-VSCodeEditionTable)[0]
$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the shim on PATH, with no executable beside its folder
    $install = Add-FakeVSCodeShim -Fixture $sandbox

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $install.Shim -Actual $result `
        -Message 'With no executable beside it, the shim itself is the answer'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the executable where the shim says it should be
    $exe = Join-Path $install.InstallRoot $stable.Exe
    [File]::WriteAllText($exe, '')

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $exe -Actual $result -Message 'The executable beside the shim''s folder wins over the shim'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - only the extensionless bin\code, which Windows cannot start
    Reset-VSCodeSandbox -Fixture $sandbox
    $null = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code'

    # Act
    $results = @(Get-VSCodeExecutable)

    # Assert
    Assert-Equal -Expected 0 -Actual $results.Count -Message 'A shim Windows cannot start is not the answer'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
