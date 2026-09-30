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
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'5.0.0' }
$alpha = [PSCustomObject]@{ Name = 'Probe.Alpha'; MinimumVersion = [Version]'1.0.0' }
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'2.0.0' }

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module

# Act
$run = Get-WhatIfOutput -CaptureError { Install-RequiredModule -Module $missing -WhatIf }

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count -Message '-WhatIf installs nothing'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target "Probe.Missing 5.0.0 or later".') `
    -Actual $run.Messages -Message '-WhatIf names the module and the version it would install'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module

# Act - two missing modules and a satisfied one, from the pipeline
$run = Get-WhatIfOutput -CaptureError { $alpha, $present, $missing | Install-RequiredModule -WhatIf }

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count -Message '-WhatIf installs none of the piped modules'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing for them'
Assert-Equal -Expected @(
    'What if: Performing the operation "Install module" on target "Probe.Alpha 1.0.0 or later".'
    'What if: Performing the operation "Install module" on target "Probe.Missing 5.0.0 or later".'
) -Actual $run.Messages -Message 'and names each one it would install, but not the one already satisfied'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module

# Act - an array, by position
$run = Get-WhatIfOutput -CaptureError { Install-RequiredModule @($present, $alpha) -WhatIf }

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count `
    -Message '-WhatIf with an array by position installs nothing'
Assert-Equal -Expected @('What if: Performing the operation "Install module" on target "Probe.Alpha 1.0.0 or later".') `
    -Actual $run.Messages -Message 'and names only the module that is missing'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Install-RequiredModule -Module $null -WhatIf } `
    -MessageLike "*Cannot bind argument to parameter 'Module' because it is null*" `
    -Message '-WhatIf still refuses a missing -Module'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module

# Act
Install-RequiredModule -Module $missing -WhatIf:$false

# Assert
Assert-Equal -Expected 'Probe.Missing' -Actual ($global:FakeInstallCalls.Name -join ', ') `
    -Message '-WhatIf:$false installs as usual'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the session itself previews every change
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module
$global:WhatIfPreference = $true
try {
    # Act
    Install-RequiredModule -Module $missing -WhatIf:$false

    # Assert
    Assert-Equal -Expected @('Probe.Missing') -Actual @($global:FakeInstallCalls | ForEach-Object { $_.Name }) `
        -Message '-WhatIf:$false installs even when the session previews: Install-Module is told so too'
}
finally {
    $global:WhatIfPreference = $false
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the session itself asks before every change
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module
$global:ConfirmPreference = 'Low'
try {
    # Act
    $run = Invoke-Capturing { Install-RequiredModule -Module $missing -Confirm:$false }

    # Assert
    Assert-Equal -Expected $null -Actual $run.Error `
        -Message '-Confirm:$false asks nothing even when the session asks: Install-Module is told so too'
    Assert-Equal -Expected @('Probe.Missing') -Actual @($global:FakeInstallCalls | ForEach-Object { $_.Name }) `
        -Message 'and the module is installed'
}
finally {
    $global:ConfirmPreference = 'High'
}

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
