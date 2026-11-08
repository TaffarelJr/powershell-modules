#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/ConvertTo-GitHubActionsAnnotationValue.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$usable = @(
    @{ Name = 'File'; Value = 'a.ps1'; Expected = 'a.ps1'; Message = 'A file path is passed on as text' }
    @{ Name = 'Title'; Value = 'T'; Expected = 'T'; Message = 'as is a title' }
    @{ Name = 'Line'; Value = 7; Expected = 7; Message = 'A number of 1 or more is passed on' }
    @{ Name = 'Line'; Value = 5.0; Expected = 5; Message = 'as is a whole number of another numeric type' }
    @{ Name = 'EndLine'; Value = 6L; Expected = 6; Message = 'a long one' }
    @{ Name = 'Column'; Value = [byte]3; Expected = 3; Message = 'a byte' }
    @{ Name = 'Line'; Value = [bigint]8; Expected = 8; Message = 'a BigInteger' }
    @{ Name = 'Line'; Value = [Int128]::new(0, 9); Expected = 9; Message = 'a 128-bit one' }
    @{ Name = 'Line'; Value = [UInt128]::new(0, 10); Expected = 10; Message = 'signed or not' }
    @{ Name = 'Line'; Value = [int]::MaxValue; Expected = [int]::MaxValue; Message = 'up to the largest line there is' }
)

# Act / Assert
foreach ($case in $usable) {
    $actual = ConvertTo-GitHubActionsAnnotationValue -Name $case.Name -Value $case.Value
    Assert-Equal -Expected $case.Expected -Actual $actual -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$unusable = @(
    @{ Name = 'File'; Value = $null; Message = 'A $null file is not given' }
    @{ Name = 'Title'; Value = '  '; Message = 'nor is a blank title' }
    @{ Name = 'Line'; Value = 0; Message = 'nor a line of 0' }
    @{ Name = 'EndLine'; Value = 'TODO here'; Message = 'nor text where a number belongs' }
    @{ Name = 'EndColumn'; Value = '12'; Message = 'not even numeric text, as a matched line may be' }
    @{ Name = 'Column'; Value = -3; Message = 'nor a negative number' }
    @{ Name = 'Line'; Value = 2.5; Message = 'nor a fraction' }
    @{ Name = 'Line'; Value = 5000000000L; Message = 'nor a number too large for a line' }
    @{ Name = 'Line'; Value = [bigint]::Pow(10, 30); Message = 'however it is held' }
    @{ Name = 'Line'; Value = $true; Message = 'nor a Boolean' }
    @{ Name = 'Line'; Value = [char]'5'; Message = 'nor a character' }
    @{ Name = 'Line'; Value = [double]::NaN; Message = 'nor a value that is not a number at all' }
)

# Act / Assert
foreach ($case in $unusable) {
    $actual = @(ConvertTo-GitHubActionsAnnotationValue -Name $case.Name -Value $case.Value)
    Assert-Equal -Expected 0 -Actual $actual.Count -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$text = @(
    @{
        Value = '12'
        Expected = 12
        Message = 'With -Strict, for a value given on the command line, whole-number text is a number'
    }
    @{ Value = '05'; Expected = 5; Message = 'leading zeros and all' }
    @{ Value = ' 7 '; Expected = 7; Message = 'and spaces around it' }
)

# Act / Assert
foreach ($case in $text) {
    $actual = ConvertTo-GitHubActionsAnnotationValue -Name 'EndColumn' -Value $case.Value -Strict
    Assert-Equal -Expected $case.Expected -Actual $actual -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$refused = @(
    @{
        Name = 'Title'
        Value = ''
        Like = '-Title is blank: give a title, or leave it out.'
        Message = 'With -Strict, a blank title throws'
    }
    @{
        Name = 'File'
        Value = ' '
        Like = '-File is blank: give the file''s path, or leave it out.'
        Message = 'as does a blank file'
    }
    @{
        Name    = 'EndLine'
        Value   = 0
        Like    = '-EndLine is 0, but it must be from 1 to 2147483647: give one in that range, or leave it out.'
        Message = 'as does a whole number below 1'
    }
    @{
        Name    = 'Line'
        Value   = '2147483648'
        Like    = '-Line is 2147483648, but it must be from 1 to 2147483647: give one in that range, or leave it out.'
        Message = 'or above the largest line, text or not'
    }
    @{
        Name    = 'Line'
        Value   = 2.5
        Like    = "-Line is '2.5', which is not a whole number: give one from 1 to 2147483647, or leave it out."
        Message = 'and a fraction'
    }
    @{
        Name    = 'Column'
        Value   = [char]'5'
        Like    = '-Column is a character, not a number: give 5, not `[char`]5.'
        Message = 'and a character, saying so'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock { ConvertTo-GitHubActionsAnnotationValue -Name $case.Name -Value $case.Value -Strict } `
        -MessageLike $case.Like -Message $case.Message
}

exit (Complete-TestRun)
