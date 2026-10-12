#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the README's own usage, in a new pwsh that imports only this module.
# A new pwsh reading its module analysis cache loads the Utility commands'
# assembly in the background, so it may be there before the first command runs;
# pointing the cache at a file that is not there usually leaves it out. A host
# that loads it at startup whatever the cache cannot give this case, so the file
# is skipped there, and TypeReferences.Tests.ps1 covers the same rule without a
# new process.
$noCache = @{ PSModuleAnalysisCachePath = Join-Path ([IO.Path]::GetTempPath()) "workflowcommands-no-cache-$([Guid]::NewGuid())" }
$script = @'
$loaded = [AppDomain]::CurrentDomain.GetAssemblies().GetName().Name -contains 'Microsoft.PowerShell.Commands.Utility'
"utility loaded: $loaded"
$env:GITHUB_OUTPUT = Join-Path ([IO.Path]::GetTempPath()) "workflowcommands-fresh-$PID.txt"
[IO.File]::WriteAllBytes($env:GITHUB_OUTPUT, [byte[]]@())
try {
    Set-GitHubActionsOutput -Name 'version' -Value '1.2.3'
    Write-GitHubActionsWarning -Message 'Falling back to the cached value' -File 'build.ps1' -Line 42
    Invoke-GitHubActionsLogGroup 'Restoring packages' {
        Write-Host 'restored'
    }
    Write-GitHubActionsNotice 'noticed'
    Write-GitHubActionsError 'failed'
}
finally {
    Remove-Item -LiteralPath $env:GITHUB_OUTPUT
}
'@

# Act
$fresh = $null
try {
    foreach ($attempt in 1..20) {
        $run = Invoke-ChildPowerShell -Script $script -Environment $noCache
        if ($run.Lines.Count -gt 0 -and $run.Lines[0] -eq 'utility loaded: False') {
            $fresh = $run
            break
        }
    }
}
finally {
    Remove-Item -LiteralPath $noCache.PSModuleAnalysisCachePath -ErrorAction Ignore
}

if ($null -eq $fresh) {
    exit (Skip-TestRun -Reason 'Every new pwsh had already loaded its Utility assembly, so the case could not be set up.')
}

# Assert
Assert-Equal -Expected @(
    'utility loaded: False'
    '::warning file=build.ps1,line=42::Falling back to the cached value'
    '::group::Restoring packages'
    'restored'
    '::endgroup::'
    '::notice::noticed'
    '::error::failed'
) -Actual $fresh.Lines `
    -Message 'Every function works in a new pwsh before it has loaded the Utility commands'' assembly'
Assert-Equal -Expected '' -Actual $fresh.Error -Message 'and writes no error'

exit (Complete-TestRun)
