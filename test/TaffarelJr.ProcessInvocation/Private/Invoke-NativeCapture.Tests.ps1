#Requires -Version 7.0
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/Invoke-NativeCapture.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a successful command
$result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-Equal -Expected 0 -Actual $result.ExitCode -Message 'A successful command reports exit code 0'
Assert-Equal -Expected 1 -Actual @($result.Output).Count -Message 'Output is always an array'
Assert-That -Condition ($result.Output -contains 'hello') -Message 'Output contains what the command printed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a failing command is reported, not thrown
$result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 7')

# Assert
Assert-Equal -Expected 7 -Actual $result.ExitCode -Message 'A non-zero exit code is reported, not thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command that prints nothing still returns an array, not $null
$result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 0')

# Assert
Assert-Equal -Expected 0 -Actual @($result.Output).Count -Message 'A silent command returns an empty array'
Assert-That -Condition ($null -ne $result.Output) -Message 'Output is never $null, even when empty'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - stderr is merged into the captured output
$result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "[Console]::Error.WriteLine('to stderr'); Write-Output 'to stdout'")

# Assert
Assert-That -Condition (($result.Output -join "`n") -match 'to stderr') -Message 'stderr output is present in the merged result'
Assert-That -Condition (($result.Output -join "`n") -match 'to stdout') -Message 'stdout output is also present'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -StdIn is piped to the command rather than passed as an argument
$result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', '$input') -StdIn 'piped-value'

# Assert
Assert-That -Condition ($result.Output -contains 'piped-value') -Message '-StdIn is piped to the command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - output decodes as UTF-8 regardless of the console's own encoding,
# and that encoding is restored afterward rather than left pinned to UTF-8
$originalEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [Encoding]::Latin1
    $result = Invoke-NativeCapture -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "Write-Output 'cafe-$([char]0xE9)'")

    # Assert
    Assert-That -Condition (($result.Output -join "`n") -match [Regex]::Escape("cafe-$([char]0xE9)")) -Message 'Non-ASCII output decodes correctly regardless of the inherited console encoding'
    Assert-Equal -Expected ([Encoding]::Latin1).CodePage -Actual ([Console]::OutputEncoding).CodePage -Message 'The console encoding is restored to what it was before the call, not left pinned to UTF-8'
}
finally {
    [Console]::OutputEncoding = $originalEncoding
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a genuinely nonexistent command
# raises its own error rather than being captured as a normal failure
try {
    Invoke-NativeCapture -Command 'this-command-does-not-exist-xyz' -Arguments @()
    Assert-That -Condition $false -Message 'A nonexistent command throws (did not throw)'
}
catch {
    Assert-That -Condition $true -Message 'A nonexistent command raises its own error rather than returning a normal ExitCode/Output result'
}

exit (Complete-TestRun)
