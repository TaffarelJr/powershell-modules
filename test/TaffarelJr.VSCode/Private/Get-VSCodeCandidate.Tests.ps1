#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$stable, $insiders = Get-VSCodeEditionTable
$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - the sandbox has no ProgramW6432, no ProgramFiles(x86), and
    # nothing on PATH
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'The per-user install folder comes first, then the machine-wide one'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a 32-bit PowerShell's view: ProgramFiles is the 32-bit folder,
    # and ProgramW6432 the 64-bit one
    $x64 = Join-Path $sandbox.Root 'ProgramW6432'
    $x86 = Join-Path $sandbox.Root 'ProgramFilesX86'
    [Environment]::SetEnvironmentVariable('ProgramW6432', $x64, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $x86, 'Process')

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
        (Join-Path $x64 $stable.Folder $stable.Exe)
        (Join-Path $x86 $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'ProgramW6432 and ProgramFiles(x86) each add a folder, the 32-bit one last'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a 64-bit PowerShell's view: ProgramW6432 is ProgramFiles again
    [Environment]::SetEnvironmentVariable('ProgramW6432', $sandbox.ProgramFiles.ToUpperInvariant(), 'Process')

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
        (Join-Path $x86 $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'A folder named twice, in any casing, is a candidate once'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function named code, which Get-Command also finds
    function global:code { 'not an executable' }

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)
    Remove-Item -Path function:global:code

    # Assert
    Assert-Equal -Expected 3 -Actual $candidates.Count -Message 'A function named code adds no candidate'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an edition with different folder and exe names
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $insiders)

    # Assert
    $expected = Join-Path $sandbox.LocalAppData 'Programs' $insiders.Folder $insiders.Exe
    Assert-Equal -Expected $expected -Actual $candidates[0] -Message 'The edition''s own folder and exe names are used'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
