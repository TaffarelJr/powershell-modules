#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

#───────────────────────────────────────────────────────────────────────────────
# Act - a range on one line, with columns
$oneLine = @(Get-WorkflowCommand {
        & $module { Write-GitHubActionsAnnotation -Command 'warning' -Message 'm' -Line 4 -EndLine 4 -Column 2 -EndColumn 2 }
    })

# Assert
Assert-Equal -Expected @('::warning line=4,endLine=4,col=2,endColumn=2::m') -Actual $oneLine `
    -Message 'Columns on a single line, end equal to start, are passed on'

#───────────────────────────────────────────────────────────────────────────────
# Act - a range of lines, without columns
$lines = @(Get-WorkflowCommand {
        & $module { Write-GitHubActionsAnnotation -Command 'notice' -Message 'm' -File 'a.ps1' -Line 3 -EndLine 9 }
    })

# Assert
Assert-Equal -Expected @('::notice file=a.ps1,line=3,endLine=9::m') -Actual $lines `
    -Message 'A range of lines with no columns is passed on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - positions the runner would move or drop without a word
$cases = @(
    @{
        Position = @{ EndLine = 5 }
        Like     = '-EndLine 5 was given without -Line, which the runner would read as the start line instead: give -Line too.'
        Message  = 'An end line without a start line is refused, as the runner would read it as the start line'
    }
    @{
        Position = @{ Line = 1; EndColumn = 4 }
        Like     = '-EndColumn 4 was given without -Column, which the runner would read as the start column instead: give -Column too.'
        Message  = 'An end column without a start column is refused, as the runner would read it as the start column'
    }
    @{
        Position = @{ Column = 3 }
        Like     = '-Column was given without -Line, so the runner would drop the columns: give -Line too.'
        Message  = 'A column without a line is refused, as the runner would drop it'
    }
    @{
        Position = @{ Line = 1; EndLine = 3; Column = 2; EndColumn = 4 }
        Like     = 'Columns point within a single line, but -Line 1 and -EndLine 3 differ, so the runner would drop the columns: leave out the columns or the end line.'
        Message  = 'Columns across several lines are refused, as the runner would drop them'
    }
    @{
        Position = @{ Line = 5; EndLine = 3 }
        Like     = '-EndLine 3 is before -Line 5, so the runner would drop both: swap them.'
        Message  = 'An end line before the start line is refused, as the runner would drop both'
    }
    @{
        Position = @{ Line = 1; Column = 5; EndColumn = 2 }
        Like     = '-EndColumn 2 is before -Column 5, so the runner would drop both: swap them.'
        Message  = 'An end column before the start column is refused, as the runner would drop both'
    }
)

# Act / Assert
foreach ($case in $cases) {
    $written = @(Get-WorkflowCommand {
            Assert-Throws -ScriptBlock {
                & $module {
                    param($position)
                    Write-GitHubActionsAnnotation -Command 'warning' -Message 'm' @position
                } $case.Position
            } -MessageLike $case.Like -Message $case.Message
        })
    Assert-Equal -Expected 0 -Actual $written.Count -Message "and nothing is written ($($case.Message))"
}

exit (Complete-TestRun)
