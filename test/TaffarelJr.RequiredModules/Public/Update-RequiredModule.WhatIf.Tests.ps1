#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets and reads the caller-session state the code under test uses.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'5.0.0' }

#───────────────────────────────────────────────────────────────────────────────
# Act - an installed module and a missing one, under -WhatIf
Assert-FakeInstaller -Module $module
$run = Get-WhatIfOutput -CaptureError { $present, $missing | Update-RequiredModule -WhatIf }

# Assert
Assert-Equal -Expected 0 -Actual ($global:FakeUpdateCalls.Count + $global:FakeInstallCalls.Count) `
    -Message '-WhatIf updates nothing and installs nothing'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
Assert-Equal -Expected @(
    'What if: Performing the operation "Update module" on target "Probe.Present".'
    'What if: Performing the operation "Update module" on target "Probe.Missing".'
) -Actual $run.Messages -Message '-WhatIf names each module it would update or install'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Update-RequiredModule -Module $null -WhatIf } `
    -MessageLike "*Cannot bind argument to parameter 'Module' because it is null*" `
    -Message '-WhatIf still refuses a missing -Module'
Assert-Throws -ScriptBlock { Update-RequiredModule -Module ([PSCustomObject]@{ Name = 'Az*' }) -WhatIf } `
    -MessageLike "*'Az*'*is not a valid module name*" `
    -Message 'and a name that is not a module name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the session itself previews every change
$global:FakeUpdateCalls.Clear()
Assert-FakeInstaller -Module $module
$global:WhatIfPreference = $true
try {
    # Act
    Update-RequiredModule -Module $present -WhatIf:$false

    # Assert
    Assert-Equal -Expected @('Probe.Present') -Actual @($global:FakeUpdateCalls | ForEach-Object { $_.Name }) `
        -Message '-WhatIf:$false updates even when the session previews: Update-Module is told so too'
}
finally {
    $global:WhatIfPreference = $false
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the session itself asks before every change
$global:FakeUpdateCalls.Clear()
Assert-FakeInstaller -Module $module
$global:ConfirmPreference = 'Low'
try {
    # Act
    $run = Invoke-Capturing { Update-RequiredModule -Module $present -Confirm:$false }

    # Assert
    Assert-Equal -Expected $null -Actual $run.Error `
        -Message '-Confirm:$false asks nothing even when the session asks: Update-Module is told so too'
    Assert-Equal -Expected @('Probe.Present') -Actual @($global:FakeUpdateCalls | ForEach-Object { $_.Name }) `
        -Message 'and the module is updated'
}
finally {
    $global:ConfirmPreference = 'High'
}

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
