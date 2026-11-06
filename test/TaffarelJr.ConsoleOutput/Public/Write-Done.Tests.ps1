#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

# The markers Write-Success, Write-Skip and Write-Warn put in front of a fresh line.
$successMarker = "$([char]0x2705) "
$skipMarker = "$([char]0x23ED)$([char]0xFE0F)  "
$warnMarker = "$([char]0x26A0)$([char]0xFE0F)  "

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - closes an open Doing line with the default wording
$messages = @(Get-HostMessage { Write-Doing 'building'; Write-Done })

# Assert
Assert-Equal -Expected 2 -Actual $messages.Count `
    -Message 'Write-Doing plus Write-Done together print two pieces of text'
Assert-Equal -Expected ' done' -Actual $messages[1].Message -Message 'Write-Done closes the line with "done" by default'
Assert-Equal -Expected 'Green' -Actual $messages[1].Color -Message 'and in green'
Assert-That -Condition (-not $messages[1].NoNewLine) -Message 'and ends the line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - -Skip closes it as "already done" instead
$skipped = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Skip })

# Assert
Assert-Equal -Expected ' already done' -Actual $skipped[1].Message -Message '-Skip closes the line as "already done"'
Assert-Equal -Expected 'DarkGray' -Actual $skipped[1].Color -Message 'and in dark gray'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - -Warn closes it as a warning
$warned = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Warn })

# Assert
Assert-Equal -Expected ' warning' -Actual $warned[1].Message -Message '-Warn closes the line as "warning"'
Assert-Equal -Expected 'Yellow' -Actual $warned[1].Color -Message 'in yellow'
Assert-That -Condition (-not $warned[1].NoNewLine) -Message 'and ends the line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - -Warn with an outcome of its own, which is how "would create" is said
$warnedText = @(Get-HostMessage { Write-Doing 'creating'; Write-Done -Warn -Text 'would create' })

# Assert
Assert-Equal -Expected ' would create' -Actual $warnedText[1].Message -Message '-Warn keeps the -Text it is given'
Assert-Equal -Expected 'Yellow' -Actual $warnedText[1].Color -Message 'in yellow'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a blank -Text with -Warn
$blankWarn = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Text '  ' -Warn })

# Assert
Assert-Equal -Expected ' warning' -Actual $blankWarn[1].Message `
    -Message 'A blank -Text with -Warn keeps the -Warn wording'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a Skip is not a warning
Assert-Throws -ScriptBlock { Write-Done -Skip -Warn } -MessageLike '*Parameter set cannot be resolved*' `
    -Message '-Skip and -Warn cannot be given together'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - with no Write-Doing open, -Warn prints a fresh Write-Warn line instead
$freshWarned = @(Get-HostMessage { Write-Done -Warn })
$freshWarnedText = @(Get-HostMessage { Write-Done -Warn -Text 'would create' })

# Assert
Assert-Equal -Expected @("  ${warnMarker}warning") -Actual @($freshWarned.Message) `
    -Message 'The fallback with -Warn is one Write-Warn line'
Assert-Equal -Expected @("  ${warnMarker}would create") -Actual @($freshWarnedText.Message) `
    -Message 'and carries a custom -Text too'
Assert-Equal -Expected 'Yellow' -Actual $freshWarned[0].Color -Message 'in yellow'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a custom -Text overrides the default wording
$custom = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Text 'up to date' })

# Assert
Assert-Equal -Expected ' up to date' -Actual $custom[1].Message `
    -Message 'A custom -Text replaces the default outcome wording'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Text that came out blank, as a $null or empty variable does
Reset-ConsoleOutputState -Module $module

# Act
$empty = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Text '' })
Reset-ConsoleOutputState -Module $module
$nothing = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Text $null })
Reset-ConsoleOutputState -Module $module
$blankSkip = @(Get-HostMessage { Write-Doing 'building'; Write-Done -Text '  ' -Skip })

# Assert
Assert-Equal -Expected ' done' -Actual $empty[1].Message -Message 'An empty -Text keeps the default wording'
Assert-Equal -Expected ' done' -Actual $nothing[1].Message -Message 'and so does a $null one'
Assert-Equal -Expected ' already done' -Actual $blankSkip[1].Message `
    -Message 'and a blank one with -Skip keeps the -Skip wording'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - an outcome with more than one line
$multi = @(Get-HostMessage {
        Invoke-Indented -Width 2 {
            Write-Doing 'building'
            Write-Done -Text "ok`nsee the log"
        }
    })

# Assert
Assert-Equal -Expected @('    ▶ building ...', ' ok', '      see the log') -Actual @($multi.Message) `
    -Message 'A later line of the outcome is indented under the Doing text, not left in column 0'
Assert-Equal -Expected @('Cyan', 'Green', 'Green') -Actual @($multi.Color) `
    -Message 'and every line of the outcome has its color'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - the Doing line had an indent of its own
$overridden = @(Get-HostMessage { Write-Doing 'building' -Indent 4; Write-Done -Text "ok`nsee the log" })

# Assert
Assert-Equal -Expected @('      ▶ building ...', ' ok', '        see the log') -Actual @($overridden.Message) `
    -Message 'A later line of the outcome follows the Doing line''s own indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - Write-Done consumes the open line, so a later writer needs no closer
$after = @(Get-HostMessage { Write-Doing 'building'; Write-Done; Write-Info 'next' })

# Assert
Assert-Equal -Expected 3 -Actual $after.Count `
    -Message 'Nothing is open after Write-Done, so the next writer prints straight away'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - with no Write-Doing open, a fresh Write-Success / Write-Skip line
# is printed instead of a bare continuation
$fresh = @(Get-HostMessage { Write-Done })
$freshSkipped = @(Get-HostMessage { Write-Done -Skip })
$freshCustom = @(Get-HostMessage { Write-Done -Text 'custom' })

# Assert
Assert-Equal -Expected @("  ${successMarker}done") -Actual @($fresh.Message) `
    -Message 'The fallback is one Write-Success line with the default wording, and nothing else'
Assert-Equal -Expected @("  ${skipMarker}already done") -Actual @($freshSkipped.Message) `
    -Message 'The fallback with -Skip is one Write-Skip line'
Assert-Equal -Expected @("  ${successMarker}custom") -Actual @($freshCustom.Message) `
    -Message 'The fallback carries a custom -Text too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - one Doing has one outcome: a second piped value finds nothing open
$piped = @(Get-HostMessage { Write-Doing 'building'; 'first', 'second' | Write-Done })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' first', "  ${successMarker}second") -Actual @($piped.Message) `
    -Message 'Only the first piped value closes the line; the next prints as its own Write-Success line'

exit (Complete-TestRun)
