#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a person at the keyboard
Use-FakeHost -Module $module

# Act - a scriptblock that succeeds immediately
$lines = @(Get-HostOutput { $script:immediate = Invoke-InputRetry -ScriptBlock { 'ok' } })

# Assert
Assert-Equal -Expected 'ok' -Actual $script:immediate -Message 'A successful first attempt returns the result'
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'and prints no warning'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - fails once, then succeeds
Use-FakeHost -Module $module
$script:calls = 0

# Act
$lines = @(Get-HostOutput {
        $script:retried = Invoke-InputRetry -ScriptBlock {
            $script:calls++
            if ($script:calls -lt 2) {
                throw 'not yet'
            }
            return 'eventually ok'
        }
    })

# Assert
Assert-Equal -Expected 'eventually ok' -Actual $script:retried -Message 'A later successful attempt returns its result'
Assert-Equal -Expected 2 -Actual $script:calls `
    -Message 'The scriptblock ran exactly as many times as it took to succeed'
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'The failed attempt warned once'
Assert-That -Condition ($lines[0] -like '*not yet') -Message 'with the reason it failed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - always fails, bounded to a small -MaxAttempt
Use-FakeHost -Module $module
$script:attempts = 0

# Act / Assert - exhausting every attempt rethrows the last failure, unwrapped
Assert-Throws -ScriptBlock {
    $null = Invoke-InputRetry -MaxAttempt 3 -ScriptBlock {
        $script:attempts++
        throw "attempt $script:attempts failed"
    }
} -MessageLike 'attempt 3 failed' -Message 'Exhausting every attempt throws the last failure, not a generic wrapper'
Assert-Equal -Expected 3 -Actual $script:attempts -Message '-MaxAttempt bounds the number of attempts exactly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-FakeHost -Module $module
$script:attempts = 0

# Act / Assert - one attempt is allowed, and means no retry
Assert-Throws -ScriptBlock {
    $null = Invoke-InputRetry -MaxAttempt 1 -ScriptBlock {
        $script:attempts++
        throw 'only once'
    }
} -MessageLike 'only once' -Message '-MaxAttempt 1 tries once and rethrows'
Assert-Equal -Expected 1 -Actual $script:attempts -Message 'without trying again'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a count of no attempts at all would silently do nothing
Assert-Throws -ScriptBlock { Invoke-InputRetry -MaxAttempt 0 -ScriptBlock { 'ran' } } -MessageLike '*MaxAttempt*' `
    -Message '-MaxAttempt 0 is refused rather than returning nothing without running the block'
Assert-Throws -ScriptBlock { Invoke-InputRetry -MaxAttempt -1 -ScriptBlock { 'ran' } } -MessageLike '*MaxAttempt*' `
    -Message 'and so is a negative one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nobody to ask again
Use-FakeHost -Module $module -UserInteractive $false
$script:attempts = 0

# Act
$lines = @(Get-HostOutput {
        try {
            $null = Invoke-InputRetry -ScriptBlock {
                $script:attempts++
                throw 'no one can fix this'
            }
        }
        catch {
            $script:thrown = $_.Exception.Message
        }
    })

# Assert
Assert-Equal -Expected 1 -Actual $script:attempts -Message 'A session with nobody to re-ask tries once'
Assert-Equal -Expected 'no one can fix this' -Actual $script:thrown -Message 'and fails with the real reason'
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'without warning of a retry that is not coming'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a mistake in how the block is written, not in an answer
Use-FakeHost -Module $module
$script:attempts = 0

# Act
$requirementOnly = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        'x' | Assert-Input -Requirement 'must be digits'
    }
}
$requirementAttempts = $script:attempts
$script:attempts = 0
$badParameter = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        Read-Input -Prompt 'x' -NoSuchParameter
    }
}
$badParameterAttempts = $script:attempts

# Assert
Assert-Equal -Expected 1 -Actual $requirementAttempts `
    -Message 'A call that can never succeed - a -Requirement with no -Pattern - is tried once'
Assert-Equal -Expected '-Requirement has no effect without -Pattern' -Actual $requirementOnly.Exception.Message `
    -Message 'and fails with its own message'
Assert-Equal -Expected 1 -Actual $badParameterAttempts -Message 'and so is a parameter that does not exist'
Assert-That -Condition ($badParameter.Exception.Message -like "*NoSuchParameter*") -Message 'which says what it was'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pattern that is not a regular expression
Use-FakeHost -Module $module
$script:attempts = 0

# Act
$badPattern = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        'x' | Assert-Input -Pattern '[unclosed'
    }
}

# Assert
Assert-Equal -Expected 1 -Actual $script:attempts -Message 'A -Pattern that is not a regular expression is tried once'
Assert-That -Condition ($badPattern.Exception.Message -like '-Pattern is not a valid regular expression: *') `
    -Message 'and says so'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a choice list that repeats an option, and a -Validate that returns no text
Use-FakeHost -Module $module
$script:attempts = 0

# Act
$null = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        'x' | Assert-Input -Choice 'a', 'A'
    }
}
$choiceAttempts = $script:attempts
$script:attempts = 0
$validateError = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        'x' | Assert-Input -Validate { 0 }
    }
}
$validateAttempts = $script:attempts
$validateId = if ($validateError) { $validateError.FullyQualifiedErrorId } else { '' }

# Assert
Assert-Equal -Expected 1 -Actual $choiceAttempts -Message 'A -Choice list that repeats an option is tried once'
Assert-Equal -Expected 1 -Actual $validateAttempts `
    -Message 'and so is a -Validate that returns something that is not text'
Assert-Equal -Expected 'ValidateReturnedNonString,Assert-Input,Invoke-InputRetry' -Actual $validateId `
    -Message 'which fails the call instead of letting the answer through'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an answer that does not convert to the type the block wants
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'abc', '5'

# Act
$lines = @(Get-HostOutput { $script:port = Invoke-InputRetry -ScriptBlock { [int](Read-Input -Prompt 'Port') } })

# Assert
Assert-Equal -Expected 5 -Actual $script:port `
    -Message 'An answer that fails a conversion is asked again, and the next good one is returned'
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'after one warning'
Assert-That -Condition ($lines[0] -like '*Cannot convert value "abc"*') -Message 'that says why the answer was refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - errors the block's own code throws, whatever their category
Use-FakeHost -Module $module
$script:attempts = 0
$script:recordAttempts = 0

# Act
$null = Get-HostOutput {
    $script:argumentResult = Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        if ($script:attempts -lt 3) {
            throw [ArgumentException]::new('not that one')
        }

        'third time'
    }
    $script:recordResult = Invoke-InputRetry -ScriptBlock {
        $script:recordAttempts++
        if ($script:recordAttempts -lt 2) {
            throw [ErrorRecord]::new([Exception]::new('mine'), 'InvalidPattern', 'InvalidArgument', $null)
        }

        'second time'
    }
}

# Assert
Assert-Equal -Expected 'third time' -Actual $script:argumentResult `
    -Message 'An ArgumentException from the block is retried'
Assert-Equal -Expected 3 -Actual $script:attempts -Message 'as often as it takes'
Assert-Equal -Expected 'second time' -Actual $script:recordResult `
    -Message 'and so is an InvalidArgument error that only shares an id with one of the module''s own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - more mistakes in how the block is written
Use-FakeHost -Module $module
$script:attempts = 0

# Act
$notFound = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        Read-Inputt -Prompt 'x'
    }
}
$notFoundAttempts = $script:attempts
$script:attempts = 0
$badDefault = Get-ThrownError {
    Invoke-InputRetry -ScriptBlock {
        $script:attempts++
        Select-Choice -Prompt 'x' -Option 'a', 'b' -Default 'c'
    }
}
$badDefaultAttempts = $script:attempts

# Assert
Assert-Equal -Expected 1 -Actual $notFoundAttempts -Message 'A command that does not exist is tried once'
Assert-That -Condition ($notFound.Exception -is [CommandNotFoundException]) `
    -Message 'and fails with PowerShell''s own error'
Assert-Equal -Expected 1 -Actual $badDefaultAttempts `
    -Message 'and so is a Select-Choice whose -Default is not an option'
Assert-Equal -Expected 'DefaultNotAnOption,Select-Choice,Invoke-InputRetry' -Actual $badDefault.FullyQualifiedErrorId `
    -Message 'which fails with its own error'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each way a call in the block can be mistyped, run with no host so
# a missing mandatory parameter fails instead of asking for a value
Use-FakeHost -Module $module
$mistyped = @(
    @{
        Id     = 'NamedParameterNotFound'
        Script = 'function Set-Thing { [CmdletBinding()] param($Port) }; Set-Thing -Prot 1'
    }
    @{
        Id     = 'AmbiguousParameter'
        Script = 'function Set-Thing { [CmdletBinding()] param($PortA, $PortB) }; Set-Thing -Port 1'
    }
    @{
        Id     = 'AmbiguousParameterSet'
        Script = 'function Set-Thing { [CmdletBinding()] param([Parameter(ParameterSetName = ''A'')]$A, [Parameter(ParameterSetName = ''B'')]$B) }; Set-Thing -A 1 -B 2'
    }
    @{
        Id     = 'MissingMandatoryParameter'
        Script = 'function Set-Thing { [CmdletBinding()] param([Parameter(Mandatory)]$Port) }; Set-Thing'
    }
    @{
        Id     = 'MissingArgument'
        Script = 'function Set-Thing { [CmdletBinding()] param($Port) }; Set-Thing -Port'
    }
    @{
        Id     = 'PositionalParameterNotFound'
        Script = 'function Set-Thing { [CmdletBinding()] param() }; Set-Thing 1'
    }
    @{
        Id     = 'ParameterAlreadyBound'
        Script = 'function Set-Thing { [CmdletBinding()] param($Port) }; Set-Thing -Port 1 -Port 2'
    }
)

foreach ($row in $mistyped) {
    # Act
    $measured = Measure-HostlessRetry -Script $row.Script

    # Assert
    Assert-Equal -Expected "$($row.Id),Set-Thing,Invoke-InputRetry" -Actual $measured.ErrorId `
        -Message "A block whose call fails with $($row.Id) fails with that error"
    Assert-Equal -Expected 1 -Actual $measured.Attempts -Message 'after being tried once'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a parameter that refuses the typed answer
function Set-Port {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory)]
        [int]$Port
    )

    $Port
}

function Set-Size {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 10)]
        [int]$Size
    )

    $Size
}

Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'abc', '5', '99', '5'

# Act
$portLines = @(Get-HostOutput { $script:port = Invoke-InputRetry -ScriptBlock { Set-Port -Port (Read-Input -Prompt 'Port') } })
$sizeLines = @(Get-HostOutput { $script:size = Invoke-InputRetry -ScriptBlock { Set-Size -Size (Read-Input -Prompt 'Size') } })

# Assert
Assert-Equal -Expected 5 -Actual $script:port `
    -Message 'An answer an [int] parameter cannot take is asked again, and the next good one is used'
Assert-Equal -Expected 1 -Actual $portLines.Count -Message 'after one warning'
Assert-Equal -Expected 5 -Actual $script:size -Message 'and so is an answer a [ValidateRange] parameter refuses'
Assert-Equal -Expected 1 -Actual $sizeLines.Count -Message 'also after one warning'
Assert-That -Condition ($sizeLines[0] -like '*99*') -Message 'which says why the answer was refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each of the module's own call mistakes
$mistakes = @(
    @{ Name = 'a -Validate that returns a boolean'; Call = { 'x' | Assert-Input -Validate { $true } } }
    @{ Name = 'an option with spaces around it'; Call = { Select-Choice -Prompt 'x' -Option ' a ', 'b' } }
    @{ Name = 'an option listed twice'; Call = { Select-Choice -Prompt 'x' -Option 'a', 'A' } }
)

foreach ($mistake in $mistakes) {
    Use-FakeHost -Module $module
    $script:attempts = 0
    $script:call = $mistake.Call

    # Act
    $null = Get-ThrownError {
        Invoke-InputRetry -ScriptBlock {
            $script:attempts++
            & $script:call
        }
    }

    # Assert
    Assert-Equal -Expected 1 -Actual $script:attempts -Message "A block with $($mistake.Name) is tried once"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - values handed to the block
Use-FakeHost -Module $module
$handed = Invoke-InputRetry -ArgumentList 'first', @('second', 'third') -ScriptBlock {
    param($one, $many)
    "$one|$($many -join '+')"
}

# Assert
Assert-Equal -Expected 'first|second+third' -Actual $handed `
    -Message '-ArgumentList hands each value to the block''s own parameters, an array staying whole'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - what the block writes comes back
Use-FakeHost -Module $module
$several = @(Invoke-InputRetry -ScriptBlock { 'a'; 'b' })

# Assert
Assert-Equal -Expected @('a', 'b') -Actual $several -Message 'Everything the successful attempt returns comes back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real processes with nobody to ask. Not flagged, so an
# unanswerable question is asked again until the attempts run out; flagged
# or on CI, it is asked once
$script = "try { Invoke-InputRetry -ScriptBlock { '' | Assert-Input -Require -Label 'Name' } } catch { 'FAILED: ' + `$_.Exception.Message }"
$asked = Invoke-ChildPowerShell -Script $script
$once = Invoke-ChildPowerShell -Script $script -Environment @{ CI = 'true' }
$flagged = Invoke-ChildPowerShell -Script $script -Flag '-NonInteractive'

# Assert
Assert-Equal -Expected 10 -Actual ([regex]::Matches($asked.Output, 'Name is required')).Count `
    -Message 'A session that can still be asked retries - nine warnings and then the failure, ten mentions in all'
Assert-Equal -Expected 'FAILED: Name is required' -Actual $once.Output.Trim() `
    -Message 'On CI it fails at once, with no warnings'
Assert-Equal -Expected 'FAILED: Name is required' -Actual $flagged.Output.Trim() `
    -Message 'and so does a session started with -NonInteractive'

exit (Complete-TestRun)
