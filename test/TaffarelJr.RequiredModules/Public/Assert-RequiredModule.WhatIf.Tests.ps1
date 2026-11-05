#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -Confirm is answered, or shown to fail where no one can answer, only in a
# fresh process: Invoke-AssertProcess runs those cases.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$missingData = @{ 'Probe.Missing' = @{ MinimumVersion = '1.0.0' } }
$appear = {
    param($installing)
    New-FakeModule -Root $sandbox -Name $installing.Name -Version $installing.MinimumVersion.ToString()
}
$declined = 'Required modules not satisfied: Probe.Child 1.0.0 or later.'
$notFound = 'Probe.Child 1.0.0 or later was installed but is still not found - is the install location on PSModulePath?'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-AssertSeam -Module $module -OnInstall $appear

# Act
$run = Get-WhatIfOutput -CaptureError { Assert-RequiredModule -Data $missingData -WhatIf 6>$null }

# Assert
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs -Message '-WhatIf installs nothing'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target "Probe.Missing 1.0.0 or later".') `
    -Actual $run.Messages -Message '-WhatIf names the module and the version it would install'
Assert-Equal -Expected $null -Actual $run.Error `
    -Message 'and does not fail for a module whose install it only previewed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two manifests piped in, one module in them already satisfied
Use-AssertSeam -Module $module -OnInstall $appear
$twoData = @{
    'Probe.Alpha'   = @{ MinimumVersion = '2.0.0' }
    'Probe.Present' = @{ MinimumVersion = '1.0.0' }
}

# Act
$run = Get-WhatIfOutput -CaptureError { $twoData, $missingData | Assert-RequiredModule -WhatIf 6>$null }

# Assert
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message '-WhatIf installs none of the piped manifests'' modules'
Assert-Equal -Expected @(
    'What if: Performing the operation "Install module" on target "Probe.Alpha 2.0.0 or later".'
    'What if: Performing the operation "Install module" on target "Probe.Missing 1.0.0 or later".'
) -Actual $run.Messages -Message 'and names each missing one, in name order, but not the satisfied one'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
Assert-Equal -Expected $null -Actual $run.Error -Message 'and does not fail for either previewed install'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest file naming a missing module
Use-AssertSeam -Module $module -OnInstall $appear
$missingPath = New-ManifestFile -Directory $sandbox -Name 'missing.psd1' `
    -Content "@{ 'Probe.Missing' = @{ MinimumVersion = '1.0.0' } }"

# Act
$run = Get-WhatIfOutput -CaptureError { Assert-RequiredModule -Path $missingPath -WhatIf 6>$null }

# Assert
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target "Probe.Missing 1.0.0 or later".') `
    -Actual $run.Messages -Message '-WhatIf with -Path names the module the file needs'
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs -Message 'and installs nothing'
Assert-Equal -Expected $null -Actual $run.Error -Message 'and does not fail'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Assert-RequiredModule -Path (Join-Path $sandbox 'nope.psd1') -WhatIf } `
    -MessageLike 'RequiredModules manifest not found: *nope.psd1' `
    -Message '-WhatIf still refuses a manifest that is not there'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-AssertSeam -Module $module -OnInstall $appear
$previewData = @{ 'Probe.Previewed' = @{ MinimumVersion = '1.0.0' } }

# Act
$run = Get-WhatIfOutput -CaptureError { Assert-RequiredModule -Data $previewData -WhatIf -Confirm:$false 6>$null }

# Assert
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message '-WhatIf with -Confirm:$false installs nothing'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target "Probe.Previewed 1.0.0 or later".') `
    -Actual $run.Messages -Message 'and names the install it previews'
Assert-Equal -Expected $null -Actual $run.Error -Message 'and does not fail for it'
Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-AssertSeam -Module $module -OnInstall $appear
$offData = @{ 'Probe.WhatIfOff' = @{ MinimumVersion = '1.0.0' } }

# Act
$run = Invoke-Capturing { Assert-RequiredModule -Data $offData -WhatIf:$false }

# Assert
Assert-Equal -Expected @('Probe.WhatIfOff 1.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message '-WhatIf:$false installs, as without it'
Assert-Equal -Expected $null -Actual $run.Error -Message 'and nothing fails'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same manifest twice, once with -Confirm:$false and once with
# no switch, each into a module of its own
Use-AssertSeam -Module $module -OnInstall $appear
$unaskedData = @{ 'Probe.Unasked' = @{ MinimumVersion = '1.0.0' } }
$defaultData = @{ 'Probe.Default' = @{ MinimumVersion = '1.0.0' } }

# Act
$unasked = Invoke-Capturing { Assert-RequiredModule -Data $unaskedData -Confirm:$false }
$noSwitch = Invoke-Capturing { Assert-RequiredModule -Data $defaultData }

# Assert
Assert-Equal -Expected @('Probe.Unasked 1.0.0', 'Probe.Default 1.0.0') `
    -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message '-Confirm:$false installs the missing module, as no switch does'
Assert-Equal -Expected $null -Actual $unasked.Error -Message 'and nothing fails'
Assert-Equal -Expected $null -Actual $noSwitch.Error -Message 'as with no switch'
Assert-Equal -Expected @('Installing Probe.Unasked 1.0.0 or later ... ', 'done') -Actual $unasked.Output `
    -Message 'and it reports the install'
Assert-Equal -Expected @('Installing Probe.Default 1.0.0 or later ... ', 'done') -Actual $noSwitch.Output `
    -Message 'the same way no switch does'

#───────────────────────────────────────────────────────────────────────────────
# Act - -Confirm where no one can answer
$noOne = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'confirm-ci') -NonInteractive -WithConfirm

# Assert
Assert-That -Condition ($noOne.Error -like 'Exception calling "ShouldProcess"*NonInteractive*') `
    -Message '-Confirm asks, so where no one can answer it fails at the question'
Assert-Equal -Expected '' -Actual $noOne.Installs -Message 'and nothing is installed without its answer'

#───────────────────────────────────────────────────────────────────────────────
# Act - -Confirm, answered yes
$yes = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'confirm-yes') -WithConfirm -Answer 'y'

# Assert
Assert-Equal -Expected 'Probe.Child 1.0.0' -Actual $yes.Installs -Message 'A yes to -Confirm installs the module'
Assert-Equal -Expected $null -Actual $yes.Error -Message 'and nothing fails'

#───────────────────────────────────────────────────────────────────────────────
# Act - -Confirm, answered no
$no = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'confirm-no') -WithConfirm -Answer 'n'

# Assert
Assert-Equal -Expected '' -Actual $no.Installs -Message 'A no to -Confirm installs nothing'
Assert-Equal -Expected $declined -Actual $no.Error -Message 'and the module said no to is named in the failure'

#───────────────────────────────────────────────────────────────────────────────
# Act - -Confirm for two modules, yes to the first and no to the second
$mixed = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'confirm-mixed') -WithConfirm `
    -Name 'Probe.First', 'Probe.Second' -Answer 'y', 'n'

# Assert
Assert-Equal -Expected 'Probe.First 1.0.0' -Actual $mixed.Installs `
    -Message '-Confirm asks about each module: only the one said yes to is installed'
Assert-Equal -Expected 'Required modules not satisfied: Probe.Second 1.0.0 or later.' -Actual $mixed.Error `
    -Message 'and the failure names the one said no to, and not the one installed'

#───────────────────────────────────────────────────────────────────────────────
# Act - a yes to -Confirm, through the module's own Install-RequiredModule
$real = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'confirm-real') -WithConfirm -Answer 'y' `
    -RealInstall

# Assert
Assert-Equal -Expected 'Probe.Child' -Actual $real.ModuleInstall `
    -Message 'One yes to -Confirm reaches Install-Module: Install-RequiredModule does not ask again'
Assert-Equal -Expected $notFound -Actual $real.Error `
    -Message 'and the check after it runs (the stand-in Install-Module makes no module appear)'

#───────────────────────────────────────────────────────────────────────────────
# Act - no switch, in a session whose ConfirmPreference asks, answered no
$preference = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $sandbox 'preference') `
    -SessionConfirmPreference 'Medium' -Answer 'n'

# Assert
Assert-Equal -Expected '' -Actual $preference.Installs `
    -Message 'A ConfirmPreference of Medium asks as -Confirm does, and a no installs nothing'
Assert-Equal -Expected $declined -Actual $preference.Error -Message 'and names the module in the failure'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
