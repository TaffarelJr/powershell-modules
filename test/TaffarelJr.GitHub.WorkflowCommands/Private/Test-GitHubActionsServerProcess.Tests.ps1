#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/Test-GitHubActionsServerProcess.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the arguments pwsh is started with as a server
$servers = @(
    @{
        Argument = @('-s', '-NoLogo', '-NoProfile')
        Message = 'A background job''s or out-of-process runspace''s process is a server'
    }
    @{ Argument = @('-NoLogo', '-servermode'); Message = 'as is one with the switch in full, after another' }
    @{ Argument = @('--ServerMode'); Message = 'in any casing, with two dashes' }
    @{ Argument = @('/s'); Message = 'or a slash' }
    @{ Argument = @('-sshs', '-NoLogo'); Message = 'SSH remoting''s process is a server' }
    @{ Argument = @('-SSHServerMode'); Message = 'with the switch in full' }
    @{ Argument = @('-nam'); Message = 'as is named-pipe remoting''s' }
    @{ Argument = @('-so'); Message = 'and socket remoting''s' }
    @{
        Argument = @('-ExecutionPolicy', 'Bypass', '-s')
        Message = 'A switch''s value is skipped, not taken for a script'
    }
)

# Act / Assert
foreach ($case in $servers) {
    foreach ($onWindows in $true, $false) {
        $actual = Test-GitHubActionsServerProcess -Argument $case.Argument -OnWindows $onWindows
        Assert-Equal -Expected $true -Actual $actual -Message "$($case.Message) (on Windows: $onWindows)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the arguments of an ordinary process
$ordinary = @(
    @{ Argument = @(); Message = 'A process started with no arguments is not a server' }
    @{ Argument = @('-NoProfile', '-File', 'step.ps1'); Message = 'nor is a step''s script' }
    @{ Argument = @('-Command', 'x', '-s'); Message = 'and what follows -Command is the command''s own' }
    @{ Argument = @('-f', 'step.ps1', '-s'); Message = 'as is what follows -File, however short' }
    @{ Argument = @('step.ps1', '-s'); Message = 'or a script path' }
    @{ Argument = @('/tmp/deploy.ps1', '-Name', 'x'); Message = 'one that starts with a slash included' }
    @{ Argument = @('/home/runner/x.ps1', '-s'); Message = 'whatever follows it' }
    @{ Argument = @('-File:x.ps1', '-s'); Message = 'An argument that is no switch of pwsh''s is read as the script' }
    @{ Argument = @('-Command:x', '-s'); Message = 'however much it looks like one' }
    @{ Argument = @('-isswait', '-s'); Message = 'as is a switch only a debug build has' }
    @{ Argument = @('-sta', '-NoLogo'); Message = 'A switch that only starts with s is not the server one' }
    @{ Argument = @('-ss'); Message = 'nor is a form pwsh does not accept' }
    @{ Argument = @('', '-NoProfile'); Message = 'An empty argument is passed over' }
)

# Act / Assert
foreach ($case in $ordinary) {
    foreach ($onWindows in $true, $false) {
        $actual = Test-GitHubActionsServerProcess -Argument $case.Argument -OnWindows $onWindows
        Assert-Equal -Expected $false -Actual $actual -Message "$($case.Message) (on Windows: $onWindows)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - switches pwsh has on Windows only
$windowsOnly = @(
    @{ Argument = @('-v2so'); Message = 'The second socket server mode is a server' }
    @{ Argument = @('-to', 'token', '-s'); Message = 'and -Token takes a value' }
    @{ Argument = @('-utc', '2024-01-02T03:04:05Z', '-s'); Message = 'as does -UtcTimestamp' }
)

# Act / Assert
foreach ($case in $windowsOnly) {
    $onWindows = Test-GitHubActionsServerProcess -Argument $case.Argument -OnWindows $true
    $elsewhere = Test-GitHubActionsServerProcess -Argument $case.Argument -OnWindows $false
    Assert-Equal -Expected $true -Actual $onWindows -Message "$($case.Message) on Windows"
    Assert-Equal -Expected $false -Actual $elsewhere `
        -Message "but elsewhere it is no switch, so it starts the script ($($case.Message))"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - this test file runs as `pwsh -File`
Assert-Equal -Expected $false -Actual (Test-GitHubActionsServerProcess) `
    -Message 'By default this process''s own arguments are read'

exit (Complete-TestRun)
