#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets and reads the caller-session state the code under test uses.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot 'RequiredModulesTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '1.0.0'
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'1.0.0' }
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$wanted = @{ 'Probe.Missing' = @{ MinimumVersion = '1.0.0' } }
Assert-FakeInstaller -Module $module

# Act
$run = Get-WhatIfOutput -CaptureError {
    Invoke-WhatIfCaller -Call { Assert-RequiredModule -Data $wanted } -WhatIf
}

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count `
    -Message 'Assert-RequiredModule called from a command run with -WhatIf installs nothing'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target ' +
        '"Probe.Missing 1.0.0 or later".') `
    -Actual $run.Messages -Message 'and says what it would have installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Assert-FakeInstaller -Module $module

# Act
$run = Get-WhatIfOutput -CaptureError {
    Invoke-WhatIfCaller -Call { Install-RequiredModule -Module $missing } -WhatIf
}

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count `
    -Message 'Install-RequiredModule called from a command run with -WhatIf installs nothing'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target ' +
        '"Probe.Missing 1.0.0 or later".') `
    -Actual $run.Messages -Message 'and says what it would have installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Assert-FakeInstaller -Module $module

# Act
$run = Get-WhatIfOutput -CaptureError {
    Invoke-WhatIfCaller -Call { Update-RequiredModule -Module $present } -WhatIf
}

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeUpdateCalls.Count `
    -Message 'Update-RequiredModule called from a command run with -WhatIf updates nothing'
Assert-Equal -Expected @('What if: Performing the operation "Update module" on target "Probe.Present".') `
    -Actual $run.Messages -Message 'and says what it would have updated'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
