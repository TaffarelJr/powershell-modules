#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-VSCodeCandidate.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# The CLI shim is a code.cmd, found through PATHEXT - a shape only Windows has.
if (-not $IsWindows) {
    Write-Host 'skipped - the CLI shim is a Windows .cmd'
    exit (Complete-TestRun)
}

$stable = @{
    Name   = 'Stable'
    Cli    = 'code'
    Exe    = 'Code.exe'
    Folder = 'Microsoft VS Code'
}

$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install laid out as VS Code's own is: bin\code.cmd beside
    # the executable's folder
    $installRoot = Join-Path $sandbox.Root 'custom-install'
    $shimFolder = Join-Path $installRoot 'bin'
    New-Item -ItemType Directory -Path $shimFolder | Out-Null
    $shim = Join-Path $shimFolder 'code.cmd'
    Set-Content -LiteralPath $shim -Value '@echo off'
    $env:PATH = $shimFolder

    # Act
    $candidates = Get-VSCodeCandidate -Edition $stable

    # Assert
    Assert-Equal -Expected (Join-Path $installRoot 'Code.exe') -Actual $candidates[0] -Message 'The executable beside the shim''s folder is the first candidate'
    Assert-Equal -Expected $shim -Actual $candidates[1] -Message 'The shim itself is the second'
    Assert-Equal -Expected 4 -Actual $candidates.Count -Message 'The install-folder candidates follow the shim ones'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
