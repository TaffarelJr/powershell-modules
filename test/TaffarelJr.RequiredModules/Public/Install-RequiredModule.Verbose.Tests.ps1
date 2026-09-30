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
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'5.0.0' }
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }
$command = 'Running Install-Module -Name Probe.Missing -MinimumVersion 5.0.0 -Scope CurrentUser -Force ' +
    '-SkipPublisherCheck'

#───────────────────────────────────────────────────────────────────────────────
# Act
$all = @(Get-VerboseLine { Install-RequiredModule -Module $missing -Verbose })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines `
    -Message '-Verbose shows the Install-Module command, with the switches it passes, before it runs'
Assert-Equal -Expected 1 -Actual $global:FakeInstallCalls.Count -Message 'and the install is made as usual'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-VerboseLine { Install-RequiredModule -Module $missing })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Without -Verbose nothing is said'

#───────────────────────────────────────────────────────────────────────────────
# Act - the verbose switch given to a command of another module, which calls this one without it
$all = @(Get-VerboseLine { Invoke-InstallCaller -Module $missing -Verbose })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines -Message 'A call made from another module under -Verbose is shown too'

#───────────────────────────────────────────────────────────────────────────────
# Act - the verbose preference of the session, with the caller given no switch
$previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
try {
    $all = @(Get-VerboseLine { Invoke-InstallCaller -Module $missing })
}
finally {
    Set-Variable -Name VerbosePreference -Scope Global -Value $previous
}
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines -Message 'and so is one made under the session''s verbose preference'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-VerboseLine { Invoke-InstallCaller -Module $missing })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'A call from another module that asked for nothing says nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - the session asks for verbose output, and the call itself turns it off
$previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
try {
    $lines = @(Get-VerboseLine { Install-RequiredModule -Module $missing -Verbose:$false })
}
finally {
    Set-Variable -Name VerbosePreference -Scope Global -Value $previous
}

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message '-Verbose:$false on the call itself wins over the session'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeInstallCalls.Clear()

# Act
$all = @(Get-VerboseLine { Install-RequiredModule -Module $missing -Verbose -WhatIf })

# Assert
Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like 'Running *' }).Count `
    -Message 'An install that -WhatIf skips is not shown as run'
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count -Message 'and is not made'

#───────────────────────────────────────────────────────────────────────────────
# Act
$all = @(Get-VerboseLine { Install-RequiredModule -Module $present -Verbose })

# Assert
Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like 'Running *' }).Count `
    -Message 'A module that is already satisfied is not installed, so no command is shown'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
