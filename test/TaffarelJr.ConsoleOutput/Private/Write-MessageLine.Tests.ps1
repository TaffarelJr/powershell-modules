#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - one line is written once, behind the lead
$one = @(Get-HostMessage { & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text 'only' -Color Green } })

# Assert
Assert-Equal -Expected 1 -Actual $one.Count -Message 'A one-line message is written once'
Assert-Equal -Expected '> only' -Actual $one[0].Message -Message 'behind the lead'
Assert-Equal -Expected 'Green' -Actual $one[0].Color -Message 'in the given color'
Assert-Equal -Expected $false -Actual $one[0].NoNewLine -Message 'and the line is ended'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several lines: the first behind the lead, the rest behind the continuation
$many = @(Get-HostMessage { & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text "a`nb`nc" -Color Cyan } })

# Assert
Assert-Equal -Expected @('> a', '  b', '  c') -Actual @($many.Message) -Message 'Later lines follow the continuation'
Assert-Equal -Expected @('Cyan') -Actual @($many.Color | Select-Object -Unique) -Message 'and all share the color'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - CRLF counts as one break, and a blank line is written bare
$crlf = @(Get-HostMessage { & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text "a`r`n`r`nb" -Color Gray } })

# Assert
Assert-Equal -Expected @('> a', '', '  b') -Actual @($crlf.Message) `
    -Message 'CRLF is one break, and a blank later line is written without the continuation'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a lone CR is a break too
$cr = @(Get-HostMessage { & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text "abc`rXY" -Color Gray } })

# Assert
Assert-Equal -Expected @('> abc', '  XY') -Actual @($cr.Message) `
    -Message 'A lone CR starts a new line instead of overwriting the start of this one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - empty text is one empty line behind the lead
$empty = @(Get-HostMessage { & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text '' -Color Gray } })

# Assert
Assert-Equal -Expected @('> ') -Actual @($empty.Message) -Message 'Empty text writes just the lead'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -NoNewline leaves only the last line open
$open = @(Get-HostMessage {
        & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text "a`nb" -Color Gray -NoNewline }
    })
$openOne = @(Get-HostMessage {
        & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text 'a' -Color Gray -NoNewline }
    })
$openBlank = @(Get-HostMessage {
        & $module { Write-MessageLine -Lead '> ' -Continuation '  ' -Text "a`n" -Color Gray -NoNewline }
    })

# Assert
Assert-Equal -Expected @($false, $true) -Actual @($open.NoNewLine) -Message '-NoNewline ends every line but the last'
Assert-Equal -Expected @($true) -Actual @($openOne.NoNewLine) -Message 'which is the first, for one line'
Assert-Equal -Expected @($false, $true) -Actual @($openBlank.NoNewLine) -Message 'and holds for a blank last line too'

exit (Complete-TestRun)
