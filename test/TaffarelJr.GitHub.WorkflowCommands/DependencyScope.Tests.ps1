#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')
$processInvocation = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
$manifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1'
Import-Module $processInvocation -Force
Import-Module $manifest -Force

$expected = 'What if: Performing the operation "Set step output" on target "***@h.example".'
$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function of the same name as one the module calls, defined in the global scope after both imports
    $null = New-CommandFile -Variable 'GITHUB_OUTPUT' -Directory $sandbox
    $calls = [System.Collections.Generic.List[string]]::new()
    $shadow = {
        param($Text)

        $calls.Add($Text)
        return 'FROM-GLOBAL'
    }.GetNewClosure()
    Set-Item -Path Function:\global:Hide-UrlCredential -Value $shadow

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsOutput -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'The module calls the command of the module it requires, not the global function of that name'
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages -Message 'and the required command did the work'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the module imported again, which runs its root module afresh
    Import-Module $manifest -Force
    $calls.Clear()

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsOutput -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'After the module is imported again with -Force, the global function is still not called'
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages -Message 'and the required command did the work'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the module it requires imported again too, then the module
    Import-Module $processInvocation -Force
    Import-Module $manifest -Force
    $calls.Clear()

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsOutput -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'After both are imported again with -Force, the global function is still not called'
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages -Message 'and the required command did the work'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the module it requires imported again on its own
    Import-Module $processInvocation -Force
    $calls.Clear()

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsOutput -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $calls.Count `
        -Message 'After only the required module is imported again with -Force, the global function is still not called'
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages -Message 'and the required command did the work'
}
finally {
    Remove-Item Function:\global:Hide-UrlCredential -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the root module imported by itself, as nothing but its manifest would have loaded the module it requires
Remove-Module TaffarelJr.GitHub.WorkflowCommands, TaffarelJr.ProcessInvocation -Force
$rootModule = Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psm1'
$caught = $null

# Act
try {
    Import-Module $rootModule -Force -ErrorAction Stop
}
catch {
    $caught = $_
}

# Assert
Assert-That -Condition ($null -ne $caught) -Message 'Importing the root module without the module it requires loaded fails'
Assert-Equal -Expected 'TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.WorkflowCommands.' `
    -Actual $caught.Exception.Message -Message 'and says which module to load first'
exit (Complete-TestRun)
