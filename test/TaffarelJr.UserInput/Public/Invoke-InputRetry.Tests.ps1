#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a scriptblock that succeeds immediately
# returns its result, with no warning printed
$lines = Get-HostOutput { $script:immediateResult = Invoke-InputRetry -ScriptBlock { 'ok' } }

# Assert
Assert-Equal -Expected 'ok' -Actual $script:immediateResult -Message 'A successful first attempt returns the result'
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A successful first attempt prints no warning'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - fails once, then succeeds
$script:callCount = 0
$eventuallySucceeds = {
    $script:callCount++
    if ($script:callCount -lt 2) { throw 'not yet' }
    return 'eventually ok'
}

# Act
$lines = Get-HostOutput { $script:retryResult = Invoke-InputRetry -ScriptBlock $eventuallySucceeds }

# Assert
Assert-Equal -Expected 'eventually ok' -Actual $script:retryResult -Message 'A later successful attempt returns its result'
Assert-Equal -Expected 2 -Actual $script:callCount -Message 'The scriptblock ran exactly as many times as it took to succeed'
Assert-That -Condition ($lines.Count -ge 1) -Message 'Each failed attempt warns before retrying'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - always fails, bounded to a small -MaxAttempt
$script:attemptCount = 0
$alwaysFails = {
    $script:attemptCount++
    throw "attempt $script:attemptCount failed"
}

# Act / Assert - exhausting every attempt rethrows the last failure, unwrapped
try {
    $null = Invoke-InputRetry -ScriptBlock $alwaysFails -MaxAttempt 3
    Assert-That -Condition $false -Message 'Exhausting every attempt throws (did not throw)'
}
catch {
    Assert-Equal -Expected 'attempt 3 failed' -Actual $_.Exception.Message -Message 'The final exception is the last attempt, not a generic wrapper message'
}

Assert-Equal -Expected 3 -Actual $script:attemptCount -Message '-MaxAttempt bounds the number of attempts exactly'

exit (Complete-TestRun)
