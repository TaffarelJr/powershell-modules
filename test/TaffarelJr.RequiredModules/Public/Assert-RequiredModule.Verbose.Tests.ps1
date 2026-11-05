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
. (Join-Path $PSScriptRoot '..' '..' 'PreferenceTestHelper.ps1')

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
Install-VerboseCaller
$missing = @{ 'Probe.Missing' = @{ MinimumVersion = '5.0.0' } }
$command = 'Running Install-Module -Name Probe.Missing -MinimumVersion 5.0.0 -Scope CurrentUser -Force ' +
    '-SkipPublisherCheck'

# The stand-in Install-Module makes no module appear, so the check after the install fails: the install
# command is shown before that, and the failure is not what these cases are about.
$ignoreFailure = { try { & $args[0] 6>$null } catch { $null = $_ } }

#───────────────────────────────────────────────────────────────────────────────
# Act
$all = @(Get-VerboseLine { & $ignoreFailure { Assert-RequiredModule -Data $missing -Verbose } })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines `
    -Message '-Verbose shows the Install-Module command of each install it makes'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-VerboseLine { & $ignoreFailure { Assert-RequiredModule -Data $missing } })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Without -Verbose nothing is said'

#───────────────────────────────────────────────────────────────────────────────
# Act - the verbose switch given to a command of another module, which calls this one without it
$all = @(Get-VerboseLine { & $ignoreFailure { Invoke-AssertCaller -Data $missing -Verbose } })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines `
    -Message 'A call made from another module under -Verbose is shown too'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-VerboseLine { & $ignoreFailure { Invoke-AssertCaller -Data $missing } })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A call from another module that asked for nothing says nothing'

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
