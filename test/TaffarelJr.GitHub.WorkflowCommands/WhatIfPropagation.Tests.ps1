#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$sandbox = New-WorkflowCommandsSandbox
$pathBefore = $env:PATH
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - each changing function, called from a function that was given -WhatIf
    $changes = @(
        @{ Call = { Add-GitHubActionsPath -Path $sandbox }; Variable = 'GITHUB_PATH'; Name = 'Add-GitHubActionsPath' }
        @{
            Call     = { Add-GitHubActionsStepSummary -Markdown '# Done' }
            Variable = 'GITHUB_STEP_SUMMARY'
            Name     = 'Add-GitHubActionsStepSummary'
        }
        @{
            Call     = { Save-GitHubActionsState -Name 'a' -Value 'b' }
            Variable = 'GITHUB_STATE'
            Name     = 'Save-GitHubActionsState'
        }
        @{
            Call     = { Set-GitHubActionsEnvironmentVariable -Name 'WFC_WHATIF_PROBE' -Value 'b' }
            Variable = 'GITHUB_ENV'
            Name     = 'Set-GitHubActionsEnvironmentVariable'
        }
        @{
            Call     = { Set-GitHubActionsOutput -Name 'a' -Value 'b' }
            Variable = 'GITHUB_OUTPUT'
            Name     = 'Set-GitHubActionsOutput'
        }
    )
    foreach ($change in $changes) {
        $path = New-CommandFile -Variable $change.Variable -Directory $sandbox

        # Act
        $call = $change.Call
        $result = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $call -WhatIf }

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Messages.Count `
            -Message "$($change.Name) called from a function given -WhatIf says what it would do"
        Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and writes nothing to its file'
    }

    Assert-Equal -Expected $null -Actual $env:WFC_WHATIF_PROBE -Message 'and sets no environment variable'
    Assert-Equal -Expected $pathBefore -Actual $env:PATH -Message 'and changes no PATH'
}
finally {
    $env:PATH = $pathBefore
    Remove-Item Env:\WFC_WHATIF_PROBE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
