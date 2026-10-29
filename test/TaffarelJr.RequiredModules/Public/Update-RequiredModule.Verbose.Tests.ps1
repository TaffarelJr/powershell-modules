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
$null = New-Module -Name RequiredModulesUpdateCaller -ScriptBlock {
    function Invoke-UpdateCaller {
        [CmdletBinding()]
        param($Module)

        Update-RequiredModule -Module $Module
    }
}
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }
$command = 'Running Update-Module -Name Probe.Present -Force'

#───────────────────────────────────────────────────────────────────────────────
# Act
$all = @(Get-VerboseLine { Update-RequiredModule -Module $present -Verbose })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines -Message '-Verbose shows the Update-Module command before it runs'
Assert-Equal -Expected 1 -Actual $global:FakeUpdateCalls.Count -Message 'and the update is made as usual'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-VerboseLine { Update-RequiredModule -Module $present })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Without -Verbose nothing is said'

#───────────────────────────────────────────────────────────────────────────────
# Act - the verbose switch given to a command of another module, which calls this one without it
$all = @(Get-VerboseLine { Invoke-UpdateCaller -Module $present -Verbose })
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines -Message 'A call made from another module under -Verbose is shown too'

#───────────────────────────────────────────────────────────────────────────────
# Act - the verbose preference of the session, with the caller given no switch
$previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
try {
    $all = @(Get-VerboseLine { Invoke-UpdateCaller -Module $present })
}
finally {
    Set-Variable -Name VerbosePreference -Scope Global -Value $previous
}
$lines = @($all | Where-Object { $_ -like 'Running *' })

# Assert
Assert-Equal -Expected @($command) -Actual $lines -Message 'and so is one made under the session''s verbose preference'

#───────────────────────────────────────────────────────────────────────────────
# Act - the session asks for verbose output, and the call itself turns it off
$previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
try {
    $lines = @(Get-VerboseLine { Update-RequiredModule -Module $present -Verbose:$false })
}
finally {
    Set-Variable -Name VerbosePreference -Scope Global -Value $previous
}

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message '-Verbose:$false on the call itself wins over the session'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeUpdateCalls.Clear()

# Act
$all = @(Get-VerboseLine { Update-RequiredModule -Module $present -Verbose -WhatIf })

# Assert
Assert-Equal -Expected 0 -Actual @($all | Where-Object { $_ -like 'Running *' }).Count `
    -Message 'An update that -WhatIf skips is not shown as run'
Assert-Equal -Expected 0 -Actual $global:FakeUpdateCalls.Count -Message 'and is not made'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
