#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

#───────────────────────────────────────────────────────────────────────────────
# Arrange - everything a message can be given as
$failure = [System.Management.Automation.ErrorRecord]::new([Exception]::new('it failed'), 'id', 'NotSpecified', $null)
$forms = @(
    @{ Given = 'plain'; Expected = 'plain'; Message = 'Text is returned as it is' }
    @{ Given = ''; Expected = ''; Message = 'an empty one too' }
    @{ Given = "a`nb"; Expected = "a`nb"; Message = 'and text with a line break' }
    @{ Given = $failure; Expected = 'it failed'; Message = 'An error record gives its message' }
    @{
        Given    = 'x TODO y' | Select-String TODO
        Expected = 'x TODO y'
        Message  = 'A Select-String match gives its line'
    }
    @{
        Given    = [PSCustomObject]@{ Message = 'from an object' }
        Expected = 'from an object'
        Message  = 'An object gives its Message'
    }
    @{ Given = [PSCustomObject]@{ Message = 7 }; Expected = '7'; Message = 'a numeric one as text' }
)

# Act / Assert
foreach ($form in $forms) {
    $actual = & $module { param($m) ConvertTo-GitHubActionsMessageText -Message $m } $form.Given
    Assert-Equal -Expected $form.Expected -Actual $actual -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects with no text to give
$refusals = @(
    @{
        Given   = [PSCustomObject]@{ Text = 'nope' }
        Like    = 'A piped object needs a Message property, or give the text: PSCustomObject.'
        Message = 'An object with no Message property is refused'
    }
    @{
        Given   = [PSCustomObject]@{ Message = $null }
        Like    = "A piped object's Message property is `$null: give it the text."
        Message = 'and so is one whose Message is $null'
    }
    @{
        Given   = 7
        Like    = 'A piped object needs a Message property, or give the text: Int32.'
        Message = 'and a number, which has none'
    }
)

# Act / Assert
foreach ($case in $refusals) {
    Assert-Throws -ScriptBlock {
        & $module { param($m) ConvertTo-GitHubActionsMessageText -Message $m } $case.Given
    } -MessageLike $case.Like -Message $case.Message
}

exit (Complete-TestRun)
