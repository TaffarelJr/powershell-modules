#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force

$originalState = $env:STATE_containerId
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:STATE_containerId = 'abc123'

    # Act / Assert
    Assert-Equal -Expected 'abc123' -Actual (Get-GitHubActionsState -Name 'containerId') `
        -Message 'The value is read from STATE_<name> in the environment'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing was saved under this name
    Remove-Item Env:\STATE_neverSaved -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Equal -Expected '' -Actual (Get-GitHubActionsState -Name 'neverSaved') `
        -Message 'A name nothing was saved under reads back as an empty string, not $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:STATE_containerId = 'abc123'

    # Act
    $outputTypes = @((Get-Command Get-GitHubActionsState).OutputType.Type.FullName)
    $value = Get-GitHubActionsState -Name 'containerId'

    # Assert
    Assert-Equal -Expected @('System.String') -Actual $outputTypes -Message 'The declared output type is a string'
    Assert-Equal -Expected 'System.String' -Actual $value.GetType().FullName -Message 'and a string is what comes back'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitHubActionsState -Name ' ' } -MessageLike '*-Name is blank: give a name.' `
        -Message 'A blank name is refused, saying so'
}
finally {
    if ($null -eq $originalState) {
        Remove-Item Env:\STATE_containerId -ErrorAction SilentlyContinue
    }
    else {
        $env:STATE_containerId = $originalState
    }
}

exit (Complete-TestRun)
