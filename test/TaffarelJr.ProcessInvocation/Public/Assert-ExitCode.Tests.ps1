#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a zero exit code does not throw
try {
    Assert-ExitCode -Name 'Build' -ExitCode 0
    Assert-That -Condition $true -Message 'A zero exit code does not throw'
}
catch {
    Assert-That -Condition $false -Message "A zero exit code does not throw (threw: $($_.Exception.Message))"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a non-zero exit code throws,
# naming the activity and the code
try {
    Assert-ExitCode -Name 'Build' -ExitCode 3
    Assert-That -Condition $false -Message 'A non-zero exit code throws (did not throw)'
}
catch {
    Assert-Equal -Expected 'Build failed with exit code 3' -Actual $_.Exception.Message -Message 'The thrown message names the activity and the exit code'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -ExitCode defaults to LASTEXITCODE
# from the most recent native call
& pwsh -NoProfile -Command 'exit 5'
try {
    Assert-ExitCode -Name 'Build'
    Assert-That -Condition $false -Message 'The default -ExitCode reads LASTEXITCODE (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like '*exit code 5*') -Message 'The default -ExitCode picked up LASTEXITCODE from the prior native call'
}

exit (Complete-TestRun)
