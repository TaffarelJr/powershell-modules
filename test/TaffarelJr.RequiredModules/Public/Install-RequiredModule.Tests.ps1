#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - shadow the real Install-Module
# so this test never hits the network or actually installs anything;
# it only verifies Install-RequiredModule calls through with the right parameters.
# Defined at global: scope, not script scope -
# Install-RequiredModule's own call to "Install-Module"
# resolves through normal command lookup from ITS module,
# not from this file's local scope,
# and when this file runs nested inside Pester's own It-block machinery
# (as it does under the coverage wrapper),
# a plain script-scoped function isn't visible from there
# even though it is when this file runs standalone.
$global:installCall = $null
function global:Install-Module {
    param($Name, $MinimumVersion, $Scope, [switch]$Force, [switch]$SkipPublisherCheck)
    $global:installCall = [PSCustomObject]@{
        Name               = $Name
        MinimumVersion     = $MinimumVersion
        Scope              = $Scope
        Force              = $Force.IsPresent
        SkipPublisherCheck = $SkipPublisherCheck.IsPresent
    }
}

$module = [PSCustomObject]@{ Name = 'Pester'; MinimumVersion = [Version]'5.0.0' }

# Act
Install-RequiredModule -Module $module

# Assert
Assert-That -Condition ($null -ne $global:installCall) -Message 'Install-RequiredModule calls through to Install-Module'
Assert-Equal -Expected 'Pester' -Actual $global:installCall.Name -Message 'Passes the module name through'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $global:installCall.MinimumVersion -Message 'Passes the minimum version through'
Assert-Equal -Expected 'CurrentUser' -Actual $global:installCall.Scope -Message 'Always installs at CurrentUser scope'
Assert-That -Condition $global:installCall.Force -Message 'Always forces the install'
Assert-That -Condition $global:installCall.SkipPublisherCheck -Message 'Always skips the publisher check'

exit (Complete-TestRun)
