#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-WorkflowCommand { Write-GitHubActionsDebug 'checked out at main' })

# Assert
Assert-Equal -Expected @('::debug::checked out at main') -Actual $lines `
    -Message 'One line is written: the debug command, with the message as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act
$piped = @(Get-WorkflowCommand { 'first', 'second' | Write-GitHubActionsDebug })

# Assert
Assert-Equal -Expected @('::debug::first', '::debug::second') -Actual $piped `
    -Message 'Each piped string is written as a line of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromObject = @(Get-WorkflowCommand { [PSCustomObject]@{ Message = 'from an object' } | Write-GitHubActionsDebug })

# Assert
Assert-Equal -Expected @('::debug::from an object') -Actual $fromObject `
    -Message 'A piped object''s Message property is taken by name, not its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - piped objects whose Message property is not text
$failure = [System.Management.Automation.ErrorRecord]::new([Exception]::new('it failed'), 'id', 'NotSpecified', $null)
$records = @(
    @{ Record = [PSCustomObject]@{ Message = 7 }; Expected = '::debug::7'; Message = 'A numeric Message is its text' }
    @{ Record = [PSCustomObject]@{ Message = $true }; Expected = '::debug::True'; Message = 'as is a boolean one' }
    @{
        Record   = [PSCustomObject]@{ Message = 'm'; Extra = 1 }
        Expected = '::debug::m'
        Message  = 'and an object with more properties gives only its Message'
    }
    @{ Record = $failure; Expected = '::debug::it failed'; Message = 'An error record gives its message' }
    @{
        Record   = 'x TODO y' | Select-String TODO
        Expected = '::debug::x TODO y'
        Message  = 'and a Select-String match gives its matched line'
    }
)

# Act / Assert
foreach ($case in $records) {
    $written = @(Get-WorkflowCommand { $case.Record | Write-GitHubActionsDebug })
    Assert-Equal -Expected @($case.Expected) -Actual $written -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a number given on the command line
$number = @(Get-WorkflowCommand { Write-GitHubActionsDebug -Message 7 })

# Assert
Assert-Equal -Expected @('::debug::7') -Actual $number -Message 'A message given on the command line is its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - piped objects with no Message to take
$refusals = @(
    @{
        Record  = [PSCustomObject]@{ Text = 'nope' }
        Like    = 'A piped object needs a Message property, or give the text: PSCustomObject.'
        Message = 'An object without a Message property is refused, not written as its text'
    }
    @{
        Record  = [PSCustomObject]@{ Message = $null }
        Like    = "A piped object's Message property is `$null: give it the text."
        Message = 'and so is one whose Message holds nothing'
    }
)

# Act / Assert
foreach ($case in $refusals) {
    Install-FakeLineWriter
    Assert-Throws -ScriptBlock { $case.Record | Write-GitHubActionsDebug } -MessageLike $case.Like `
        -Message $case.Message
    Assert-Equal -Expected @() -Actual @(Get-WrittenLine) -Message 'and no line is written'
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a message needing escaping
$escaped = @(Get-WorkflowCommand { Write-GitHubActionsDebug "100%`nfree" })

# Assert
Assert-Equal -Expected @('::debug::100%25%0Afree') -Actual $escaped `
    -Message 'The message is escaped before being written'

#───────────────────────────────────────────────────────────────────────────────
# Act
$empty = @(Get-WorkflowCommand { Write-GitHubActionsDebug '' })

# Assert
Assert-Equal -Expected @('::debug::') -Actual $empty -Message 'An empty message is allowed'

exit (Complete-TestRun)
