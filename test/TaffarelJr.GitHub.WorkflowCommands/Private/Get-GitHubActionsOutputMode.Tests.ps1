#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands
$probe = '& (Get-Module TaffarelJr.GitHub.WorkflowCommands) { Get-GitHubActionsOutputMode }'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - this test file runs in pwsh's own console host
Assert-Equal -Expected 'Console' -Actual (& $module { Get-GitHubActionsOutputMode }) `
    -Message 'The step''s console process writes straight to the log'

#───────────────────────────────────────────────────────────────────────────────
# Act
$threaded = Invoke-ChildPowerShell -Script (
    "Start-ThreadJob { param(`$m) Import-Module `$m; $probe } -ArgumentList '$((Resolve-Path -LiteralPath $script:ModuleManifest).Path)' " +
    '| Wait-Job | Receive-Job')

# Assert
Assert-Equal -Expected @('Runspace') -Actual $threaded.Lines `
    -Message 'A thread job in that process is another runspace of it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$remote = Invoke-OutOfProcessScript -Script $probe

# Assert
Assert-Equal -Expected @('Host') -Actual $remote.Output -Message 'A runspace in a server process goes through the host'

#───────────────────────────────────────────────────────────────────────────────
# Act
$manifest = (Resolve-Path -LiteralPath $script:ModuleManifest).Path
$nested = Invoke-OutOfProcessScript -Script "1 | ForEach-Object -Parallel { Import-Module '$manifest'; $probe }"

# Assert
Assert-Equal -Expected @('Host') -Actual $nested.Output `
    -Message 'as does a ForEach-Object -Parallel block inside one, though its host is a default one'

#───────────────────────────────────────────────────────────────────────────────
# Act
$streaming = Invoke-ChildPowerShell -Script (
    "Start-ThreadJob -StreamingHost `$Host { param(`$m) Import-Module `$m; $probe } " +
    "-ArgumentList '$manifest' | Wait-Job | Receive-Job")

# Assert
Assert-Equal -Expected @('Runspace') -Actual $streaming.Lines `
    -Message 'A thread job sharing the console host is still another runspace, not the console''s own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$cases = @(
    @{
        HostName = 'ConsoleHost'
        Own = $true
        Server = $false
        Expected = 'Console'
        Message = 'The console host''s own runspace is the console'
    }
    @{
        HostName = 'ConsoleHost'
        Own = $false
        Server = $false
        Expected = 'Runspace'
        Message = 'another runspace sharing that host is not'
    }
    @{
        HostName = 'Default Host'
        Own = $false
        Server = $false
        Expected = 'Runspace'
        Message = 'nor is one with a default host'
    }
    @{
        HostName = 'Default Host'
        Own = $false
        Server = $true
        Expected = 'Host'
        Message = 'In a server process every runspace goes through the host'
    }
    @{ HostName = 'ConsoleHost'; Own = $true; Server = $true; Expected = 'Host'; Message = 'whatever its host' }
    @{ HostName = 'ServerRemoteHost'; Own = $false; Server = $true; Expected = 'Host'; Message = 'its own included' }
    @{
        HostName = 'Visual Studio Code Host'
        Own = $false
        Server = $false
        Expected = 'Host'
        Message = 'as does a host that is no step process'
    }
)

# Act / Assert
foreach ($case in $cases) {
    $mode = & $module {
        param($case)
        Get-GitHubActionsOutputMode -HostName $case.HostName -OwnRunspace $case.Own -ServerProcess $case.Server
    } $case
    Assert-Equal -Expected $case.Expected -Actual $mode -Message $case.Message
}

exit (Complete-TestRun)
