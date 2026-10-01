#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a successful command reports Ok and its output
$result = Invoke-NativeRead -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-That -Condition $result.Ok -Message 'A zero exit code reports Ok'
Assert-That -Condition ($result.Output -contains 'hello') -Message 'Output is captured on success too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a failing command is reported, not thrown
$result = Invoke-NativeRead -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 3')

# Assert
Assert-That -Condition (-not $result.Ok) -Message 'A non-zero exit code reports Ok as false, rather than throwing'
Assert-Equal -Expected 3 -Actual $result.ExitCode -Message 'The real exit code is reported, not just discarded into a boolean'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a tolerated failure resets LASTEXITCODE
# so a later check is not fooled
$global:LASTEXITCODE = 0
$null = Invoke-NativeRead -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 99')
Assert-Equal -Expected 0 -Actual $LASTEXITCODE -Message 'LASTEXITCODE is reset to 0 after a tolerated failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - stderr output does not, by itself, make Ok false
$result = Invoke-NativeRead -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('chatty but fine'); exit 0")

# Assert
Assert-That -Condition $result.Ok -Message 'stderr output alone does not flip a zero-exit command to failed'
Assert-That -Condition (($result.Output -join "`n") -match 'chatty but fine') -Message 'The stderr content is still present in Output'

exit (Complete-TestRun)
