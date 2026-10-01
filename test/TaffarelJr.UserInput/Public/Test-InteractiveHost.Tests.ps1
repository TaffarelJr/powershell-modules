#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - this file itself always runs via
# `pwsh -NonInteractive -File`, the same as every test in this repo,
# so this is a real (not simulated) non-interactive check
Assert-That -Condition (-not (Test-InteractiveHost)) -Message 'Running under -NonInteractive is correctly detected as non-interactive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - CI environment variables win
# even if the launch flag didn't already settle it
$originalCi = $env:CI
try {
    $env:CI = 'true'

    # Act / Assert
    Assert-That -Condition (-not (Test-InteractiveHost)) -Message 'A CI environment variable is treated as non-interactive'
}
finally {
    $env:CI = $originalCi
}

exit (Complete-TestRun)
