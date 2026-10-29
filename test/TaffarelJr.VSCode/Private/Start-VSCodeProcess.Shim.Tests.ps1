#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
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
    # Arrange - arguments cmd.exe would read as commands, redirections, or
    # variables instead of passing them on
    $install = Add-FakeVSCodeShim -Fixture $sandbox
    $unsafe = @('C:\work\R&D', 'a|b', 'a<b', 'a>b', 'a^b', '100%', 'say "hi"', 'wow!')

    # Act / Assert
    foreach ($argument in $unsafe) {
        Assert-Throws -ScriptBlock {
            Start-VSCodeProcess -Executable $install.Shim -Argument @('--new-window', $argument)
        } -MessageLike '*cmd.exe would misread*Code.exe*' `
            -Message "An argument holding a cmd character is refused for a batch file: $argument"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act - give a launch that should not have happened the time to show
    $ran = Wait-TestFile -Path $install.Received -TimeoutSeconds 3

    # Assert
    Assert-That -Condition (-not $ran) -Message 'The refused launches never ran the shim'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with a space and no cmd character
    $clean = Join-Path $sandbox.Root 'clean folder'
    New-Item -ItemType Directory -Path $clean | Out-Null

    # Act
    Start-VSCodeProcess -Executable $install.Shim -Argument @($clean)
    $arrived = Wait-TestFile -Path $install.Received

    # Assert
    Assert-That -Condition $arrived -Message 'A clean argument still launches through the shim'
    Assert-Equal -Expected $clean -Actual ([File]::ReadAllText($install.Received).Trim()) `
        -Message 'and reaches it whole'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same shim under the other batch extension
    $batInstall = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code.bat'

    # Act / Assert
    foreach ($argument in $unsafe) {
        Assert-Throws -ScriptBlock {
            Start-VSCodeProcess -Executable $batInstall.Shim -Argument @('--new-window', $argument)
        } -MessageLike '*cmd.exe would misread*Code.exe*' `
            -Message "An argument holding a cmd character is refused for a .bat file too: $argument"
    }

    # Act - give a launch that should not have happened the time to show
    $batRan = Wait-TestFile -Path $batInstall.Received -TimeoutSeconds 3

    # Assert
    Assert-That -Condition (-not $batRan) -Message 'and the refused launches never ran it'

    # Act
    Start-VSCodeProcess -Executable $batInstall.Shim -Argument @($clean)
    $batArrived = Wait-TestFile -Path $batInstall.Received

    # Assert
    Assert-That -Condition $batArrived -Message 'A clean argument still launches through a .bat shim'
    Assert-Equal -Expected $clean -Actual ([File]::ReadAllText($batInstall.Received).Trim()) `
        -Message 'and reaches it whole'
}
finally {
    Pop-Location
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
