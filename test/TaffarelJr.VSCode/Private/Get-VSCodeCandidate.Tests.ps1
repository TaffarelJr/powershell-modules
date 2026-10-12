#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-VSCodeCandidate.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$stable = @{
    Name   = 'Stable'
    Cli    = 'code'
    Exe    = 'Code.exe'
    Folder = 'Microsoft VS Code'
}

$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - the sandbox has no ProgramFiles(x86) and nothing on PATH
    $candidates = Get-VSCodeCandidate -Edition $stable

    # Assert
    Assert-Equal -Expected 2 -Actual $candidates.Count -Message 'With no shim and no ProgramFiles(x86), there are two install-folder candidates'
    Assert-Equal -Expected (Join-Path $sandbox.LocalAppData 'Programs' 'Microsoft VS Code' 'Code.exe') -Actual $candidates[0] -Message 'The per-user install folder comes first'
    Assert-Equal -Expected (Join-Path $sandbox.ProgramFiles 'Microsoft VS Code' 'Code.exe') -Actual $candidates[1] -Message 'The machine-wide install folder comes second'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $x86 = Join-Path $sandbox.Root 'ProgramFilesX86'
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $x86, 'Process')

    # Act
    $candidates = Get-VSCodeCandidate -Edition $stable

    # Assert
    Assert-Equal -Expected 3 -Actual $candidates.Count -Message 'A ProgramFiles(x86) folder adds a third candidate'
    Assert-Equal -Expected (Join-Path $x86 'Microsoft VS Code' 'Code.exe') -Actual $candidates[2] -Message 'The 32-bit folder comes last'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function named code, which Get-Command also finds
    function global:code { 'not an executable' }

    # Act
    $candidates = Get-VSCodeCandidate -Edition $stable
    Remove-Item -Path function:global:code

    # Assert
    Assert-Equal -Expected 3 -Actual $candidates.Count -Message 'A function named code adds no candidate'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an edition with different folder and exe names
    $insiders = @{
        Name   = 'Insiders'
        Cli    = 'code-insiders'
        Exe    = 'Code - Insiders.exe'
        Folder = 'Microsoft VS Code Insiders'
    }

    # Act
    $candidates = Get-VSCodeCandidate -Edition $insiders

    # Assert
    Assert-Equal -Expected (Join-Path $sandbox.LocalAppData 'Programs' 'Microsoft VS Code Insiders' 'Code - Insiders.exe') -Actual $candidates[0] -Message 'The edition''s own folder and exe names are used'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
