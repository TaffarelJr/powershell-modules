#Requires -Version 7.4
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Assert-JsonValue.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every kind of value JSON can carry, nested inside each other
$list = [List[object]]::new()
$list.Add([ordered]@{ deeper = [DayOfWeek]::Monday })
$value = @{
    text     = 'x'
    letter   = [char]'c'
    flag     = $true
    whole    = 7
    big      = [long]9000000000
    real     = 1.5
    money    = [decimal]2.25
    day      = [DayOfWeek]::Friday
    when     = [datetime]::new(2026, 1, 2)
    nothing  = $null
    numbers  = @(1, 2, 3)
    list     = $list
    nested   = @{ inner = @('a', $null) }
    object   = [PSCustomObject]@{
        name  = 'x'
        items = @(1, [PSCustomObject]@{ deeper = @{ flag = $false } })
    }
}

# Act
$result = Assert-JsonValue -Key 'all.kinds' -Value $value

# Assert
Assert-Equal -Expected $null -Actual $result `
    -Message 'Strings, numbers, booleans, enums, dates, $null, lists, dictionaries and custom objects all pass, at any depth'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - settings read from a JSON file, which come back as custom objects
$fromFile = ConvertFrom-Json -InputObject '{ "files.exclude": { "**/bin": true }, "rulers": [80, 120] }'

# Act
$result = Assert-JsonValue -Key 'from.file' -Value $fromFile

# Assert
Assert-Equal -Expected $null -Actual $result -Message 'What ConvertFrom-Json returns passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not JSON, bare and nested
$file = Get-Item -LiteralPath ([Path]::GetTempPath())
$notJson = @(
    @{ Value = $file; Where = ''; Type = 'System.IO.DirectoryInfo'; Message = 'A DirectoryInfo is refused' }
    @{
        Value = { 'code' }
        Where = ''
        Type = 'System.Management.Automation.ScriptBlock'
        Message = 'A script block is refused'
    }
    @{
        Value = @(1, { 'nested' })
        Where = '[1]'
        Type = 'System.Management.Automation.ScriptBlock'
        Message = 'A script block inside an array is refused, naming its index'
    }
    @{
        Value = @{ inner = $file }
        Where = '.inner'
        Type = 'System.IO.DirectoryInfo'
        Message = 'A DirectoryInfo inside a dictionary is refused, naming its key'
    }
    @{
        Value = [PSCustomObject]@{ a = @(0, $file) }
        Where = '.a[1]'
        Type = 'System.IO.DirectoryInfo'
        Message = 'A DirectoryInfo inside a custom object is refused, naming its path'
    }
)

# Act / Assert
foreach ($case in $notJson) {
    Assert-Throws -ScriptBlock {
        Assert-JsonValue -Key 'my.setting' -Value $case.Value
    } -MessageLike "*Setting 'my.setting$([WildcardPattern]::Escape($case.Where))' has a value of type $($case.Type), which is not JSON*" `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - numbers JSON has no literal for, bare and nested
$notFinite = @(
    @{ Value = [double]::NaN; Where = ''; Text = 'NaN'; Message = 'NaN is refused' }
    @{ Value = [double]::PositiveInfinity; Where = ''; Text = 'Infinity'; Message = 'Infinity is refused' }
    @{
        Value = @(1, [double]::NegativeInfinity)
        Where = '[1]'
        Text = '-Infinity'
        Message = 'Negative infinity inside an array is refused, naming its index'
    }
    @{
        Value = @{ ratio = [float]::NaN }
        Where = '.ratio'
        Text = 'NaN'
        Message = 'A single-precision NaN inside a dictionary is refused, naming its key'
    }
)

# Act / Assert
foreach ($case in $notFinite) {
    Assert-Throws -ScriptBlock {
        Assert-JsonValue -Key 'my.number' -Value $case.Value
    } -MessageLike "*Setting 'my.number$([WildcardPattern]::Escape($case.Where))' is $($case.Text), which JSON has no number for*" `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dictionary with an entry named like its own Keys property
$shadowing = @{
    Keys  = { 'not json' }
    plain = 1
}

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-JsonValue -Key 'my.setting' -Value $shadowing
} -MessageLike "*Setting 'my.setting.Keys' has a value of type System.Management.Automation.ScriptBlock*" `
    -Message 'An entry named Keys is checked as an entry, not mistaken for the key list'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-JsonValue -Key 'files.exclude' -Value @{ 7 = $true }
} -MessageLike "*Setting 'files.exclude' has a dictionary key of type System.Int32*" `
    -Message 'A dictionary key that is not a string is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dictionary that holds itself, so it never ends
$loop = @{}
$loop['self'] = $loop

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-JsonValue -Key 'looped' -Value $loop
} -MessageLike "*Setting 'looped' is nested more than 100 levels deep*" `
    -Message 'A value that holds itself is refused, rather than walked forever'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a custom object that holds itself
$selfish = [PSCustomObject]@{ name = 'x' }
$selfish | Add-Member -NotePropertyName self -NotePropertyValue $selfish

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-JsonValue -Key 'looped.object' -Value $selfish
} -MessageLike "*Setting 'looped.object' is nested more than 100 levels deep*" `
    -Message 'A custom object that holds itself is refused too'

exit (Complete-TestRun)
