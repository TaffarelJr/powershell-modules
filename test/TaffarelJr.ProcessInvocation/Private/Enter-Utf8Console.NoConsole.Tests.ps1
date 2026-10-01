#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
foreach ($name in 'Get-ConsoleEncodingGate', 'Enter-Utf8Console', 'Exit-Utf8Console',
    'Assert-BatchFileArgument', 'Find-NativeCommand', 'Stop-NativeProcessTree',
    'Invoke-NativeProcess', 'Invoke-NativeCapture') {
    . (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private' "$name.ps1")
}
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-UrlCredential.ps1')

# Letting go of the console is a Windows call. A test process without one
# could not print its own results, so the detached run is a child of its own.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'detaching from the console is a Windows call')
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a PowerShell that lets go of its console, then runs a command.
# PowerShell's first native call after its console goes away fails on the
# console state it had cached, which a host that never had one does not
# have, so a first call takes that failure before the one that counts.
$script = @"
`$kernel = '[DllImport("kernel32.dll")] public static extern bool FreeConsole();'
Add-Type -Namespace ProcessInvocationTests -Name Console -MemberDefinition `$kernel
`$null = [ProcessInvocationTests.Console]::FreeConsole()
Import-Module '$moduleManifest'
`$null = Invoke-NativeRead -Command '$pwsh' -Argument @('-NoProfile', '-Command', 'exit 0')
`$read = Invoke-NativeRead -Command '$pwsh' -Argument @('-NoProfile', '-Command', "Write-Output 'no console needed'")
[Console]::Out.WriteLine("Ok=`$(`$read.Ok) Output=`$(`$read.Output)")
"@

# Act
$result = Invoke-NativeCapture -Command $pwsh -Arguments @('-NoProfile', '-NonInteractive', '-Command', $script) `
    -TimeoutSeconds 90

# Assert
Assert-Equal -Expected @('Ok=True Output=no console needed') -Actual $result.Output `
    -Message 'A command runs with no console attached instead of throwing, and its output comes back'

exit (Complete-TestRun)
