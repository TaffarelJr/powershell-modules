#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

# Arrange - shadow Read-Host so no test here waits on a real person.
# Defined at global: scope, not script scope -
# Read-Input's own call to Read-Host resolves through
# normal command lookup from ITS module, not from this file's local scope,
# and when this file runs nested inside Pester's own It-block machinery
# (as it does under the coverage wrapper),
# a plain script-scoped function isn't visible from there
# even though it is when this file runs standalone.
$global:readHostAnswers = [System.Collections.Generic.Queue[string]]::new()
$global:readHostPrompt = $null
function global:Read-Host {
    param(
        [Parameter(Position = 0)]
        [string]$Prompt,
        [switch]$AsSecureString
    )
    $global:readHostPrompt = $Prompt
    return $global:readHostAnswers.Dequeue()
}

# Arrange / Act - a typed answer is trimmed and returned as-is
$global:readHostAnswers.Enqueue('  hello  ')
$result = Read-Input -Prompt 'Name'

# Assert
Assert-Equal -Expected 'hello' -Actual $result -Message 'A typed answer is trimmed'

# Arrange / Act - a blank answer falls back to -Default
$global:readHostAnswers.Enqueue('')
$result = Read-Input -Prompt 'Name' -Default 'fallback'

# Assert
Assert-Equal -Expected 'fallback' -Actual $result -Message 'A blank answer resolves to -Default'

# Arrange / Act - a whitespace-only answer is treated the same as blank
$global:readHostAnswers.Enqueue('   ')
$result = Read-Input -Prompt 'Name' -Default 'fallback'

# Assert
Assert-Equal -Expected 'fallback' -Actual $result -Message 'A whitespace-only answer also resolves to -Default'

# Arrange / Act - with no -Default, a blank answer resolves to an empty string
$global:readHostAnswers.Enqueue('')
$result = Read-Input -Prompt 'Name'

# Assert
Assert-Equal -Expected '' -Actual $result -Message 'A blank answer with no -Default resolves to an empty string'

# Arrange / Act - the label shows -Choice and -Default
$global:readHostAnswers.Enqueue('x')
$null = Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private' -Default 'Public'

# Assert
Assert-That -Condition $global:readHostPrompt.Contains('Public/Private') -Message 'The label shows the available choices'
Assert-That -Condition $global:readHostPrompt.Contains('[Public]') -Message 'The label shows the default'

# Arrange / Act - -Hint lines print before the prompt
$global:readHostAnswers.Enqueue('y')
$lines = Get-HostOutput { Read-Input -Prompt 'Name' -Hint @('line one', 'line two') }

# Assert
Assert-Equal -Expected 2 -Actual $lines.Count -Message '-Hint prints one line per hint entry'
Assert-That -Condition ($lines[0] -like '*line one*') -Message 'The first hint line is printed'
Assert-That -Condition ($lines[1] -like '*line two*') -Message 'The second hint line is printed'

exit (Complete-TestRun)
