#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$result = Assert-ExitCode -Activity 'Building' -ExitCode 0

# Assert
Assert-That -Condition ($null -eq $result) -Message 'A zero exit code does not throw, and returns nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Assert-ExitCode -Activity 'Building' -ExitCode 3 } `
    -MessageLike 'Building failed with exit code 3' `
    -Message 'A non-zero exit code throws, naming the activity and the code'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the exit code of the most recent native call
& $pwsh -NoProfile -Command 'exit 5'

# Act / Assert
Assert-Throws -ScriptBlock { Assert-ExitCode 'Building' } `
    -MessageLike '*exit code 5*' `
    -Message 'The default -ExitCode picked up LASTEXITCODE from the prior native call, with the activity by position'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fresh session under strict mode, where no native command has run
$command = "Set-StrictMode -Version Latest; Import-Module '$modulePath' -Force; Assert-ExitCode 'Building'; 'no throw'"

# Act
$output = (Invoke-NativeRead -Command $pwsh -Argument @(
    '-NoProfile', '-NonInteractive', '-Command', $command
) -TimeoutSeconds 60).Output

# Assert
Assert-Equal -Expected @('no throw') -Actual $output `
    -Message 'With no native command run yet there is nothing to fail, and strict mode does not object'

exit (Complete-TestRun)
