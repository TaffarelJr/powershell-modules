#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Only the two paths reachable without a person to prompt are tested here:
# already-satisfied (no-op), and missing-in-CI (warns, then throws).
# The interactive prompt-and-install path needs a real person
# or a Read-Host stub this repo doesn't have yet -
# Test-InteractiveHost, Install-Module, and Get-MissingModuleMessage
# are each covered by their own tests instead,
# so the pieces are verified even though the full interactive path isn't.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest requiring a module that's always present
$satisfiedPath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).psd1"
@'
@{
    'Microsoft.PowerShell.Management' = @{ MinimumVersion = '3.0.0' }
}
'@ | Set-Content -LiteralPath $satisfiedPath

# Act / Assert - no-op, no throw
try {
    Assert-RequiredModule -Path $satisfiedPath
    Assert-That -Condition $true -Message 'An already-satisfied manifest does not throw'
}
catch {
    Assert-That -Condition $false -Message "An already-satisfied manifest does not throw (threw: $($_.Exception.Message))"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a hashtable passed directly, with no .psd1 file at all
try {
    Assert-RequiredModule -Data @{
        'Microsoft.PowerShell.Management' = @{ MinimumVersion = '3.0.0' }
    }
    Assert-That -Condition $true -Message 'An already-satisfied hashtable manifest does not throw'
}
catch {
    Assert-That -Condition $false -Message "An already-satisfied hashtable manifest does not throw (threw: $($_.Exception.Message))"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a hashtable piped in instead of passed as -Data
try {
    @{ 'Microsoft.PowerShell.Management' = @{ MinimumVersion = '3.0.0' } } | Assert-RequiredModule
    Assert-That -Condition $true -Message 'A piped, already-satisfied hashtable manifest does not throw'
}
catch {
    Assert-That -Condition $false -Message "A piped, already-satisfied hashtable manifest does not throw (threw: $($_.Exception.Message))"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path and -Data together is ambiguous, not a merge
try {
    Assert-RequiredModule -Path $satisfiedPath -Data @{}
    Assert-That -Condition $false -Message '-Path and -Data together throws (did not throw)'
}
catch {
    Assert-That -Condition $true -Message '-Path and -Data together throws'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest requiring a module that can never be installed,
# run in a fresh non-interactive process
# so Test-InteractiveHost is guaranteed false, the same as any real CI run
$missingPath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).psd1"
@'
@{
    ThisModuleDoesNotExistXyz = @{
        MinimumVersion   = '1.0.0'
        DocumentationUrl = 'https://example.test'
    }
}
'@ | Set-Content -LiteralPath $missingPath

$consoleOutputPath = Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1'
$userInputPath = Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1'
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$innerScript = "Import-Module '$consoleOutputPath' -Force; " +
"Import-Module '$userInputPath' -Force; " +
"Import-Module '$modulePath' -Force; " +
"Assert-RequiredModule -Path '$missingPath'"
$innerOutput = @(& pwsh -NoProfile -NonInteractive -Command $innerScript 2>&1)
$innerExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($innerExitCode -ne 0) -Message 'A missing module in a non-interactive session fails the process'
Assert-That -Condition (($innerOutput -join "`n") -like '*ThisModuleDoesNotExistXyz*') -Message 'The failure names the missing module'
Assert-That -Condition (($innerOutput -join "`n") -like '*Install-Module -Name ThisModuleDoesNotExistXyz*') -Message 'The failure includes the exact install command'
Assert-That -Condition (($innerOutput -join "`n") -like '*https://example.test*') -Message 'The failure includes the documentation link'

# Cleanup
Remove-Item -LiteralPath $satisfiedPath, $missingPath -Force

exit (Complete-TestRun)
