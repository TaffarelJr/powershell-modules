#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force

# Arrange / Act - a successful command returns its output as an array
$result = Invoke-NativeCommand -Activity 'Testing' -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "Write-Output 'hello'")

# Assert
Assert-Equal -Expected 1 -Actual $result.Count -Message 'A single line of output comes back as a one-element array'
Assert-Equal -Expected 'hello' -Actual $result[0] -Message 'The output is the line the command printed'

# Arrange / Act / Assert - a failing command throws,
# naming the activity and the exit code
try {
    Invoke-NativeCommand -Activity 'Testing' -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 7')
    Assert-That -Condition $false -Message 'A non-zero exit throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like 'Testing failed:*') -Message 'The thrown message names the activity'
    Assert-That -Condition ($_.Exception.Message -like '*exit 7*') -Message 'The thrown message names the exit code'
}

# Arrange / Act / Assert - the thrown message
# includes the command's own output as detail
try {
    Invoke-NativeCommand -Activity 'Testing' -Command 'pwsh' -Arguments @('-NoProfile', '-Command', "Write-Output 'useful detail'; exit 1")
    Assert-That -Condition $false -Message 'A failing command with output throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like '*useful detail*') -Message 'The failure message includes the command own output'
}

# Arrange / Act - a silent success still returns an array
$result = Invoke-NativeCommand -Activity 'Testing' -Command 'pwsh' -Arguments @('-NoProfile', '-Command', 'exit 0')

# Assert
Assert-Equal -Expected 0 -Actual $result.Count -Message 'A silent success returns an empty array, not $null'

# Arrange / Act - -StdIn is piped rather than exposed as an argument
$result = Invoke-NativeCommand -Activity 'Testing' -Command 'pwsh' -Arguments @('-NoProfile', '-Command', '$input') -StdIn 'a-secret-value'

# Assert
Assert-That -Condition ($result -contains 'a-secret-value') -Message '-StdIn reaches the command via its input stream'

exit (Complete-TestRun)
