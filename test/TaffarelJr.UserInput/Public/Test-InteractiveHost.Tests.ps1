#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a session started in the ordinary way, by a person
Use-FakeHost -Module $module

# Act / Assert
Assert-That -Condition (Test-InteractiveHost) `
    -Message 'A session with a user, started with no special flag, is interactive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the host says there is no user
Use-FakeHost -Module $module -UserInteractive $false

# Act / Assert
Assert-That -Condition (-not (Test-InteractiveHost)) -Message 'A host that reports no user present is not interactive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - launched with the flag, in each way it can be written
$launches = @(
    @{ Name = '-NonInteractive'; Line = @('pwsh', '-NonInteractive') }
    @{ Name = '-noni'; Line = @('pwsh', '-noni') }
    @{ Name = '-NonI'; Line = @('pwsh', '-NoProfile', '-NonI', '-File', 'x.ps1') }
)

foreach ($launch in $launches) {
    Use-FakeHost -Module $module -CommandLine $launch.Line

    # Act / Assert
    Assert-That -Condition (-not (Test-InteractiveHost)) `
        -Message "A session started with $($launch.Name) is not interactive"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the flag's name is the script's own parameter, not the session's
Use-FakeHost -Module $module -CommandLine @('pwsh', '-File', 'x.ps1', '-NonInteractive')

# Act / Assert
Assert-That -Condition (Test-InteractiveHost) `
    -Message 'A -NonInteractive that follows -File belongs to the script, so the session is still interactive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each CI system's own variable
foreach ($name in $script:CiVariableName) {
    Use-FakeHost -Module $module
    [Environment]::SetEnvironmentVariable($name, 'True')

    # Act / Assert
    Assert-That -Condition (-not (Test-InteractiveHost)) -Message "$name set to True means CI, so not interactive"

    # Act
    [Environment]::SetEnvironmentVariable($name, $null)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a CI variable set to a value that says it is not CI
$notCi = @('', '   ', '0', 'false', 'FALSE', ' False ', 'no', 'NO', 'off', ' Off ')

foreach ($value in $notCi) {
    Use-FakeHost -Module $module
    [Environment]::SetEnvironmentVariable('CI', $value)

    # Act / Assert
    Assert-That -Condition (Test-InteractiveHost) -Message "CI set to '$value' does not mean CI"

    # Act
    [Environment]::SetEnvironmentVariable('CI', $null)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - CI wins even over a session that looks interactive
Use-FakeHost -Module $module
[Environment]::SetEnvironmentVariable('GITHUB_ACTIONS', 'true')

# Act / Assert
Assert-That -Condition (-not (Test-InteractiveHost)) -Message 'A CI variable outranks a host that reports a user'

# Act
[Environment]::SetEnvironmentVariable('GITHUB_ACTIONS', $null)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real processes, started each way
$ordinary = Invoke-ChildPowerShell -Script 'Test-InteractiveHost'
$flagged = Invoke-ChildPowerShell -Script 'Test-InteractiveHost' -Flag '-NonInteractive'
$short = Invoke-ChildPowerShell -Script 'Test-InteractiveHost' -Flag '-noni'
$onCi = Invoke-ChildPowerShell -Script 'Test-InteractiveHost' -Environment @{ TF_BUILD = 'True' }

# Assert - a child is a service or a session-0 process only when this one is,
# so it is interactive exactly when this process is
Assert-Equal -Expected "$([Environment]::UserInteractive)" -Actual $ordinary.Output.Trim() `
    -Message 'A real session started in the ordinary way is interactive, though its input is closed'
Assert-Equal -Expected 'False' -Actual $flagged.Output.Trim() `
    -Message 'A real session started with -NonInteractive is not'
Assert-Equal -Expected 'False' -Actual $short.Output.Trim() -Message 'nor one started with -noni'
Assert-Equal -Expected 'False' -Actual $onCi.Output.Trim() -Message 'nor one on Azure Pipelines'

exit (Complete-TestRun)
