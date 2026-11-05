#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
$module = Get-Module TaffarelJr.ProcessInvocation

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
function global:Get-NotAProgramProbe { 'from a function' }
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $program = & $module { param($c) Find-NativeCommand -Command $c -ApplicationOnly } $pwsh

    # Assert
    Assert-That -Condition ($program -is [ApplicationInfo]) -Message 'The path of a program finds the program'
    Assert-Equal -Expected $pwsh -Actual $program.Source -Message 'and says where it is'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $function = & $module { Find-NativeCommand -Command 'Get-NotAProgramProbe' }
    $notProgram = & $module { Find-NativeCommand -Command 'Get-NotAProgramProbe' -ApplicationOnly }

    # Assert
    Assert-That -Condition ($function -is [FunctionInfo]) -Message 'A function is found when anything will do'
    Assert-That -Condition ($null -eq $notProgram) -Message 'and is not when only a program will'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $missing = & $module { Find-NativeCommand -Command 'this-command-does-not-exist-xyz' }

    # Assert
    Assert-That -Condition ($null -eq $missing) -Message 'A name nothing answers to finds nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the path of this very PowerShell, with its last letter a wildcard
    $pwshPattern = $pwsh.Substring(0, $pwsh.Length - 1) + '*'

    # Act
    $pattern = & $module { Find-NativeCommand -Command 'Get-Dat*' }
    $patternProgram = & $module { param($c) Find-NativeCommand -Command $c -ApplicationOnly } $pwshPattern

    # Assert
    Assert-That -Condition ($null -eq $pattern) `
        -Message 'A wildcard in a name is part of the name, not a pattern matching Get-Date'
    Assert-That -Condition ($null -eq $patternProgram) `
        -Message 'and in a path it is not a pattern matching another program'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function whose name really has the wildcard in it
    Set-Item -LiteralPath 'function:global:Get-Dat*' -Value { 'the literal one' }

    # Act
    $literal = & $module { Find-NativeCommand -Command 'Get-Dat*' }
    Remove-Item -LiteralPath 'function:global:Get-Dat*'

    # Assert
    Assert-That -Condition ($literal -is [FunctionInfo] -and $literal.Name -eq 'Get-Dat*') `
        -Message 'A command named exactly that is found'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a script in a folder whose name holds wildcard characters
    $bracketed = Join-Path $root 'br[1]'
    New-Item -ItemType Directory -Path $bracketed | Out-Null
    $script = Join-Path $bracketed 'say-hi.ps1'
    [File]::WriteAllText($script, "'hi'")

    # Act
    $exact = & $module { param($c) Find-NativeCommand -Command $c } $script
    $partial = & $module { param($c) Find-NativeCommand -Command $c } (Join-Path $bracketed 'say-*.ps1')

    # Assert
    Assert-Equal -Expected $script -Actual $exact.Source `
        -Message 'A path holding wildcard characters finds the file at exactly that path'
    Assert-That -Condition ($null -eq $partial) -Message 'and a pattern that merely matches the file does not'
}
finally {
    Remove-Item -Path function:global:Get-NotAProgramProbe
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
