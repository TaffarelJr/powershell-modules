#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Reports a test result to the person at the console; it is not data.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets the session preference the capture must not follow.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

function Get-CapturedUnder {
    param(
        [string]$Preference
    )

    $globalBefore = $global:InformationPreference
    $InformationPreference = $Preference
    $global:InformationPreference = $Preference
    try {
        @(Get-HostOutput { Write-Host 'from the block'; Write-Information 'informational' })
        "after: $InformationPreference, $global:InformationPreference"
    }
    finally {
        $global:InformationPreference = $globalBefore
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a single Write-Host call
$lines = Get-HostOutput { Write-Host 'one line' }

# Assert
Assert-Equal -Expected 'one line' -Actual $lines -Message 'One Write-Host call comes back as that line, exactly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - multiple calls, in order
$multiLines = @(Get-HostOutput { Write-Host 'first'; Write-Host 'second'; Write-Host 'third' })

# Assert
Assert-Equal -Expected @('first', 'second', 'third') -Actual $multiLines `
    -Message 'Three calls come back as three lines, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several calls, piped straight on
$piped = Get-HostOutput { Write-Host 'first'; Write-Host 'second' } | Measure-Object

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each call is its own pipeline item, so the result pipes straight into another command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - nothing printed at all
$noLines = Get-HostOutput { $null = 1 + 1 }
$collected = @(Get-HostOutput { $null = 1 + 1 })

# Assert
Assert-That -Condition ($null -eq $noLines) -Message 'A script block that prints nothing writes nothing'
Assert-Equal -Expected 0 -Actual $collected.Count -Message 'so wrapping the call in @() collects an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - genuine pipeline output alongside Write-Host is not captured
$mixed = @(Get-HostOutput { Write-Host 'printed'; 'returned' })

# Assert
Assert-Equal -Expected @('printed') -Actual $mixed `
    -Message 'Only the Write-Host call is captured, not the pipeline output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - Write-Information puts plain text in the same stream
$information = @(Get-HostOutput { Write-Information 'informational' -InformationAction Continue })

# Assert
Assert-Equal -Expected @('informational') -Actual $information -Message 'Write-Information is captured as its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - Write-Information given an object, not text
$object = @(Get-HostOutput { Write-Information 42 -InformationAction Continue })

# Assert
Assert-Equal -Expected @('42') -Actual $object -Message 'A non-text Write-Information value is captured as its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - two calls that suppress the newline are still two calls
$noNewline = @(Get-HostOutput { Write-Host 'a' -NoNewline; Write-Host 'b' })

# Assert
Assert-Equal -Expected @('a', 'b') -Actual $noNewline `
    -Message 'Each call is its own element, whether or not it ended a line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the caller has silenced or made fatal the information stream
$ignored = @(Get-CapturedUnder -Preference 'Ignore')
$fatal = @(Get-CapturedUnder -Preference 'Stop')

# Assert
Assert-Equal -Expected @('from the block', 'informational', 'after: Ignore, Ignore') -Actual $ignored `
    -Message ('A session that ignores the information stream still has its lines captured,' +
        ' and the preference is put back')
Assert-Equal -Expected @('from the block', 'informational', 'after: Stop, Stop') -Actual $fatal `
    -Message 'and one that would stop at the first line has them captured instead, the preference put back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a session that ignores the information stream, and a block that throws
$global:InformationPreference = 'Ignore'
$thrown = $null

# Act
try {
    try {
        $null = Get-HostOutput { throw 'boom from the block' }
    }
    catch {
        $thrown = $_
    }

    $afterThrow = "$global:InformationPreference"
}
finally {
    $global:InformationPreference = 'SilentlyContinue'
}

# Assert
Assert-Equal -Expected 'boom from the block' -Actual $thrown.Exception.Message `
    -Message 'What the block throws reaches the caller'
Assert-Equal -Expected 'Ignore' -Actual $afterThrow `
    -Message 'and the session''s own preference is put back all the same'

exit (Complete-TestRun)
