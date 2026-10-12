#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - nothing installed
    $results = @(Get-VSCodeExecutable)

    # Assert
    Assert-Equal -Expected 0 -Actual $results.Count `
        -Message 'With nothing installed, nothing comes back - not even $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a per-user Stable install
    $perUser = Add-FakeVSCode -Fixture $sandbox -Location LocalAppData

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $perUser -Actual $result -Message 'A per-user install is found under LOCALAPPDATA'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a machine-wide Stable install only
    Reset-VSCodeSandbox -Fixture $sandbox
    $machineWide = Add-FakeVSCode -Fixture $sandbox -Location ProgramFiles

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $machineWide -Actual $result -Message 'A machine-wide install is found under ProgramFiles'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - both locations
    $perUser = Add-FakeVSCode -Fixture $sandbox -Location LocalAppData

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $perUser -Actual $result -Message 'A per-user install is preferred over a machine-wide one'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Insiders only
    Reset-VSCodeSandbox -Fixture $sandbox
    $insiders = Add-FakeVSCode -Fixture $sandbox -Edition Insiders

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $insiders -Actual $result -Message 'Insiders is used when it is the only edition installed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - both editions
    $stable = Add-FakeVSCode -Fixture $sandbox -Edition Stable

    # Act
    $result = Get-VSCodeExecutable

    # Assert
    Assert-Equal -Expected $stable -Actual $result -Message 'Stable wins over Insiders when both are installed'

    #───────────────────────────────────────────────────────────────────────────
    # Act - Insiders asked for by name, with both installed
    $result = Get-VSCodeExecutable -Edition Insiders

    # Assert
    Assert-Equal -Expected $insiders -Actual $result -Message '-Edition Insiders skips Stable'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - only Insiders installed
    Reset-VSCodeSandbox -Fixture $sandbox
    $null = Add-FakeVSCode -Fixture $sandbox -Edition Insiders

    # Act
    $results = @(Get-VSCodeExecutable -Edition Stable)

    # Assert
    Assert-Equal -Expected 0 -Actual $results.Count -Message '-Edition Stable does not fall back to Insiders'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function named code, which Get-Command also finds
    Reset-VSCodeSandbox -Fixture $sandbox
    function global:code { 'not an executable' }

    # Act
    $results = @(Get-VSCodeExecutable)
    Remove-Item -Path function:global:code

    # Assert
    Assert-Equal -Expected 0 -Actual $results.Count -Message 'A function named code is not mistaken for an install'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder where the executable would be
    Reset-VSCodeSandbox -Fixture $sandbox
    $stable = @(Get-VSCodeEditionTable)[0]
    New-Item -ItemType Directory -Path (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe) | Out-Null

    # Act
    $results = @(Get-VSCodeExecutable)

    # Assert
    Assert-Equal -Expected 0 -Actual $results.Count -Message 'A folder named like the executable is not taken for it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-VSCodeExecutable -Edition 'Beta'
    } -MessageLike '*Edition*does not belong to the set*' -Message 'An unknown edition is rejected'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
