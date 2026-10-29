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

#───────────────────────────────────────────────────────────────────────────────
# Act - the real writer, in this process; it prints one empty line
$streams = @(& $module { Write-GitHubActionsLine -Line '' } *>&1)

# Assert
Assert-Equal -Expected 0 -Actual $streams.Count `
    -Message 'The line goes to none of PowerShell''s streams, so no caller can redirect or silence it'

#───────────────────────────────────────────────────────────────────────────────
# Act - a command from a call told to ignore its information stream, in a
# console whose encoding cannot hold the value
$quiet = Invoke-ChildPowerShell -Script (
    '[Console]::OutputEncoding = [Text.Encoding]::Latin1; ' +
    "Hide-GitHubActionsValue 'pässwörd-İ✓' -InformationAction Ignore")

# Assert
Assert-Equal -Expected @('::add-mask::pässwörd-İ✓') -Actual $quiet.Lines `
    -Message 'A command still reaches standard output under -InformationAction Ignore, as UTF-8 whatever the console encoding'

#───────────────────────────────────────────────────────────────────────────────
# Act - a command from a block whose information stream is thrown away
$redirected = Invoke-ChildPowerShell -Script "& { Write-GitHubActionsDebug 'still here' } 6>`$null"

# Assert
Assert-Equal -Expected @('::debug::still here') -Actual $redirected.Lines `
    -Message 'A command still reaches standard output under 6>$null'

#───────────────────────────────────────────────────────────────────────────────
# Act - a command from a block whose every stream is captured
$captured = Invoke-ChildPowerShell `
    -Script "`$log = & { Exit-GitHubActionsLogGroup; 'other' } *>&1; `"captured `$(@(`$log).Count)`""

# Assert
Assert-Equal -Expected @('::endgroup::', 'captured 1') -Actual $captured.Lines `
    -Message 'A command still reaches standard output when the caller captures *>&1, and only the block''s own output is captured'

#───────────────────────────────────────────────────────────────────────────────
# Act - a thread job in the step's own process masks a value, then prints it
$manifest = (Resolve-Path -LiteralPath $script:ModuleManifest).Path
$threaded = Invoke-ChildPowerShell -Script (
    "Start-ThreadJob { param(`$m) Import-Module `$m; Hide-GitHubActionsValue 'fake-secret'; 'using fake-secret' } " +
    "-ArgumentList '$manifest' | Wait-Job | Receive-Job")

# Assert
Assert-Equal -Expected @('::add-mask::fake-secret', 'using fake-secret') -Actual $threaded.Lines `
    -Message 'A thread job writes its commands straight to standard output, so the mask comes before the value'

#───────────────────────────────────────────────────────────────────────────────
# Act - several ForEach-Object -Parallel blocks masking and printing at once,
# while this process's host prints their output a part at a time
$parallel = Invoke-ChildPowerShell -TimeoutSeconds 300 -Script (
    "1..4 | ForEach-Object -ThrottleLimit 4 -Parallel { Import-Module '$manifest'; " +
    "foreach (`$i in 1..100) { `$secret = `"fake-secret-`$_-`$i`"; Hide-GitHubActionsValue `$secret; `"deploying with `$secret`" } }")
$report = Get-MaskReport -Line $parallel.Lines

# Assert
Assert-Equal -Expected @() -Actual $report.Torn `
    -Message 'Every command starts a line of its own, however the threads interleave'
Assert-Equal -Expected @() -Actual $report.Unmasked -Message 'and no value is printed before its mask'
Assert-Equal -Expected 400 -Actual $report.Masked -Message 'and every mask arrives'

#───────────────────────────────────────────────────────────────────────────────
# Act - thread jobs sharing the console host, masking and printing through it
$streaming = Invoke-ChildPowerShell -TimeoutSeconds 300 -Script (
    "`$jobs = 1..4 | ForEach-Object { Start-ThreadJob -StreamingHost `$Host -ArgumentList `$_, '$manifest' { " +
    "param(`$n, `$m) Import-Module `$m; foreach (`$i in 1..100) { `$secret = `"fake-secret-`$n-`$i`"; " +
    "Hide-GitHubActionsValue `$secret; Write-Host `"deploying with `$secret`" } } }; " +
    "`$null = `$jobs | Wait-Job; `$jobs | Remove-Job")
$report = Get-MaskReport -Line $streaming.Lines

# Assert
Assert-Equal -Expected @() -Actual $report.Torn `
    -Message 'A thread job printing through the console host never splits a command either'
Assert-Equal -Expected @() -Actual $report.Unmasked -Message 'nor prints a value before its mask'
Assert-Equal -Expected 400 -Actual $report.Masked -Message 'and every mask arrives'
#───────────────────────────────────────────────────────────────────────────────
# Act
$remote = Invoke-OutOfProcessScript -Script "Write-GitHubActionsDebug 'from afar'; 'done'"

# Assert
Assert-Equal -Expected 'Completed' -Actual $remote.State `
    -Message 'In an out-of-process runspace, as a background job runs in, the call completes'
Assert-Equal -Expected @('done') -Actual $remote.Output -Message 'and returns its output'
Assert-Equal -Expected 'Opened' -Actual $remote.RunspaceState `
    -Message 'and the runspace stays usable, its channel untouched'
Assert-Equal -Expected @('::debug::from afar') -Actual $remote.Information `
    -Message 'and the line reaches this process through the host'

#───────────────────────────────────────────────────────────────────────────────
# Act
$nestedParallel = Invoke-OutOfProcessScript -Script (
    "1 | ForEach-Object -Parallel { Import-Module '$manifest'; Write-GitHubActionsDebug 'from a parallel block' }; 'done'")

# Assert
Assert-Equal -Expected 'Opened' -Actual $nestedParallel.RunspaceState `
    -Message 'A ForEach-Object -Parallel block inside such a process leaves its runspace usable'
Assert-Equal -Expected @('done') -Actual $nestedParallel.Output -Message 'and the call completes'
Assert-Equal -Expected @('::debug::from a parallel block') -Actual $nestedParallel.Information `
    -Message 'and the line reaches this process through the host'

#───────────────────────────────────────────────────────────────────────────────
# Act
$nestedJob = Invoke-OutOfProcessScript -Script (
    "Start-ThreadJob { Import-Module '$manifest'; Write-GitHubActionsDebug 'from a thread job' } | Wait-Job | Receive-Job; 'done'")

# Assert
Assert-Equal -Expected 'Opened' -Actual $nestedJob.RunspaceState -Message 'as does a thread job inside such a process'
Assert-Equal -Expected @('done') -Actual $nestedJob.Output -Message 'and the call completes'
Assert-Equal -Expected @('::debug::from a thread job') -Actual $nestedJob.Information `
    -Message 'and the line reaches this process through the host'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the standard output stream swapped for one the test can read
& $module {
    $script:FakeStandardOutput = [System.IO.MemoryStream]::new()
    function script:Open-GitHubActionsStandardOutput {
        return $script:FakeStandardOutput
    }

    function script:Get-GitHubActionsOutputMode {
        return 'Console'
    }
}

# Act
& $module { Write-GitHubActionsLine -Line '::debug::é' }
$bytes = & $module { , $script:FakeStandardOutput.ToArray() }

# Assert
Assert-Equal -Expected ([System.Text.UTF8Encoding]::new($false).GetBytes("::debug::é$([Environment]::NewLine)")) `
    -Actual $bytes `
    -Message 'In the console host the line is written as UTF-8 with a line end, and nothing else'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a runspace in the step's own process, whose host may be mid-line
& $module {
    $script:FakeStandardOutput = [System.IO.MemoryStream]::new()
    function script:Get-GitHubActionsOutputMode {
        return 'Runspace'
    }
}

# Act
& $module { Write-GitHubActionsLine -Line '::debug::x' }
$bytes = & $module { , $script:FakeStandardOutput.ToArray() }

# Assert
$newLine = [Environment]::NewLine
Assert-Equal -Expected ([System.Text.Encoding]::UTF8.GetBytes("${newLine}::debug::x${newLine}")) -Actual $bytes `
    -Message 'In another runspace of the process a line break goes first, in the same write, so the command starts a line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a process whose standard output is not the log
& $module {
    $script:FakeStandardOutput = [System.IO.MemoryStream]::new()
    function script:Get-GitHubActionsOutputMode {
        return 'Host'
    }
}

# Act
$hosted = @(& $module { Write-GitHubActionsLine -Line '::debug::to the host' } 6>&1 | ForEach-Object { "$_" })
$bytes = & $module { , $script:FakeStandardOutput.ToArray() }

# Assert
Assert-Equal -Expected @('::debug::to the host') -Actual $hosted `
    -Message 'Anywhere else the line goes through Write-Host, to the information stream'
Assert-Equal -Expected 0 -Actual $bytes.Length -Message 'and nothing is written to standard output'

exit (Complete-TestRun)
