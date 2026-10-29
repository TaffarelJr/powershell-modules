#Requires -Version 7.4
using namespace System.Collections.Generic

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test defines same-named commands in the global scope, as another module or a script would.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A module calls the commands of the modules it requires through its own scope,
# so a command of the same name that turns up in the global scope later - from
# another module, or a script - does not take its place.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$consoleOutputPath = Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1'
$userInputPath = Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $consoleOutputPath -Force
Import-Module $userInputPath -Force
. (Join-Path $PSScriptRoot 'UserInputTestHelper.ps1')
Install-FakeReadHost

#───────────────────────────────────────────────────────────────────────────────
# Arrange - commands the module really calls, defined in the global scope after the imports
$global:ImpostorCalls = [List[string]]::new()
function global:Write-Warn {
    $global:ImpostorCalls.Add('Write-Warn')
}

function global:Get-Indent {
    $global:ImpostorCalls.Add('Get-Indent')
    return 0
}

Add-FakeAnswer 'no'

# Act
$answer = $null
$lines = @(Get-HostOutput { $script:answer = Confirm-Proceed -Action 'delete the branch' })

# Assert
Assert-Equal -Expected $false -Actual $answer -Message 'The gate still answers'
Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
    -Message 'and calls the required module''s commands, not the ones of the same name defined later'
Assert-That -Condition (@($lines | Where-Object { $_ -like '*Aborted by user*' }).Count -eq 1) `
    -Message 'which print the warning'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - both modules loaded again, the required one first, as a script that reloads them would
Import-Module $consoleOutputPath -Force
Import-Module $userInputPath -Force
Add-FakeAnswer 'no'

# Act
$lines = @(Get-HostOutput { $script:answer = Confirm-Proceed -Action 'delete the branch' })

# Assert
Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
    -Message 'The same holds after the modules are imported again with -Force'
Assert-That -Condition (@($lines | Where-Object { $_ -like '*Aborted by user*' }).Count -eq 1) `
    -Message 'and the warning is still printed'

Remove-Item -LiteralPath Function:\Write-Warn, Function:\Get-Indent

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the required module not loaded at all
Remove-Module -Name 'TaffarelJr.ConsoleOutput' -Force

# Act / Assert - the module's root script says what is missing, rather than leave a call to fail later
Assert-Throws -ScriptBlock {
    Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psm1') -Force
} -MessageLike '*TaffarelJr.ConsoleOutput must be loaded before TaffarelJr.UserInput.*' `
    -Message 'A module imported without a module it requires says which one has to be loaded first'

exit (Complete-TestRun)
