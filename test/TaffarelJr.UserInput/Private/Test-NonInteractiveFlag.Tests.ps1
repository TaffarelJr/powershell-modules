#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - command lines, and whether each asked for -NonInteractive
$cases = @(
    @{ Name = 'the full flag'; Line = @('pwsh', '-NonInteractive'); Expected = $true }
    @{ Name = 'the full flag in lower case'; Line = @('pwsh', '-noninteractive'); Expected = $true }
    @{ Name = 'the full flag in upper case'; Line = @('pwsh', '-NONINTERACTIVE'); Expected = $true }
    @{ Name = 'the common short form -noni'; Line = @('pwsh', '-noni'); Expected = $true }
    @{ Name = '-NonI'; Line = @('pwsh', '-NonI'); Expected = $true }
    @{ Name = 'the shortest start that is unambiguous, -non'; Line = @('pwsh', '-non'); Expected = $true }
    @{ Name = 'a slash instead of a dash'; Line = @('pwsh', '/NonInteractive'); Expected = $true }
    @{ Name = 'two dashes'; Line = @('pwsh', '--noninteractive'); Expected = $true }
    @{
        Name = 'a Windows path for the program'
        Line = @('C:\Program Files\PowerShell\7\pwsh.exe', '-NonInteractive')
        Expected = $true
    }
    @{ Name = 'a Unix path for the program'; Line = @('/usr/bin/pwsh', '-noni'); Expected = $true }
    @{
        Name = 'among other options'
        Line = @('pwsh', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-noni', '-File', 'x.ps1')
        Expected = $true
    }
    @{ Name = 'no arguments at all'; Line = @(); Expected = $false }
    @{ Name = 'only the program'; Line = @('pwsh'); Expected = $false }
    @{
        Name = 'other options that start with No'
        Line = @('pwsh', '-NoProfile', '-NoLogo', '-NoExit')
        Expected = $false
    }
    @{ Name = 'a start too short to be unambiguous, -No'; Line = @('pwsh', '-No'); Expected = $false }
    @{ Name = 'a word that is not a start of the flag'; Line = @('pwsh', '-nonsense'); Expected = $false }
    @{ Name = 'the flag with extra letters'; Line = @('pwsh', '-NonInteractives'); Expected = $false }
    @{ Name = 'a bare word with no dash'; Line = @('pwsh', 'NonInteractive'); Expected = $false }
    @{
        Name = 'after -Command, where it is part of the command'
        Line = @('pwsh', '-Command', 'Do-It', '-NonInteractive')
        Expected = $false
    }
    @{ Name = 'after -c'; Line = @('pwsh', '-c', 'Do-It', '-noni'); Expected = $false }
    @{
        Name = 'after -File, where it belongs to the script'
        Line = @('pwsh', '-File', 'x.ps1', '-NonInteractive')
        Expected = $false
    }
    @{ Name = 'after -f'; Line = @('pwsh', '-f', 'x.ps1', '-NonInteractive'); Expected = $false }
    @{
        Name = 'after -EncodedCommand'
        Line = @('pwsh', '-EncodedCommand', 'AAAA', '-NonInteractive')
        Expected = $false
    }
    @{ Name = 'after -e'; Line = @('pwsh', '-e', 'AAAA', '-NonInteractive'); Expected = $false }
    @{ Name = 'after -ec'; Line = @('pwsh', '-ec', 'AAAA', '-NonInteractive'); Expected = $false }
    @{
        Name = 'after -CommandWithArgs'
        Line = @('pwsh', '-CommandWithArgs', 'Do-It', '-NonInteractive')
        Expected = $false
    }
    @{
        Name = 'before -File, which is still the session''s own'
        Line = @('pwsh', '-NonInteractive', '-File', 'x.ps1')
        Expected = $true
    }
)

foreach ($case in $cases) {
    # Act
    $result = & $module { param($line) Test-NonInteractiveFlag -CommandLine $line } $case.Line

    # Assert
    Assert-Equal -Expected $case.Expected -Actual $result -Message "$($case.Name): $($case.Expected)"
}

exit (Complete-TestRun)
