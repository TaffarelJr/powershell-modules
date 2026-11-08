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
# Act
$bare = @(Get-WorkflowCommand { & $module { Write-GitHubActionsCommand -Command 'endgroup' } })

# Assert
Assert-Equal -Expected @('::endgroup::') -Actual $bare `
    -Message 'A command with no properties and no data is its name between the markers'

#───────────────────────────────────────────────────────────────────────────────
# Act
$full = @(Get-WorkflowCommand {
        & $module {
            $properties = [ordered]@{ title = 'a:b,c'; line = 3 }
            Write-GitHubActionsCommand -Command 'warning' -Properties $properties -Data "50%`r`ndone"
        }
    })

# Assert
Assert-Equal -Expected @('::warning title=a%3Ab%2Cc,line=3::50%25%0D%0Adone') -Actual $full `
    -Message 'Properties are written in order and escaped as properties, and the data is escaped as data'

#───────────────────────────────────────────────────────────────────────────────
# Act
$sparse = @(Get-WorkflowCommand {
        & $module {
            $properties = [ordered]@{ file = ''; line = 7; title = $null }
            Write-GitHubActionsCommand -Command 'notice' -Properties $properties -Data 'm'
        }
    })

# Assert
Assert-Equal -Expected @('::notice line=7::m') -Actual $sparse `
    -Message 'A property whose value is empty is left out, not written as key='

#───────────────────────────────────────────────────────────────────────────────
# Act
$empty = @(Get-WorkflowCommand {
        & $module {
            $properties = [ordered]@{ file = '' }
            Write-GitHubActionsCommand -Command 'notice' -Properties $properties -Data 'm'
        }
    })

# Assert
Assert-Equal -Expected @('::notice::m') -Actual $empty `
    -Message 'With every property empty, no space or property list is written'

exit (Complete-TestRun)
