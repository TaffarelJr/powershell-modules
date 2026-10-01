#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

# Arrange - shadow Read-Host so no test here waits on a real person
$global:proceedAnswer = ''
function global:Read-Host {
    param([Parameter(Position = 0)][string]$Prompt)
    return $global:proceedAnswer
}

# Arrange / Act / Assert - the literal word, in any casing, proceeds
$global:proceedAnswer = 'yes'
Assert-That -Condition (Confirm-Proceed -Action 'delete the branch') -Message "The literal word 'yes' proceeds"

$global:proceedAnswer = 'YES'
Assert-That -Condition (Confirm-Proceed -Action 'delete the branch') -Message 'Casing does not matter'

# Arrange / Act - anything else, including a short form, is a final no - no retry
$global:proceedAnswer = 'y'
$lines = Get-HostOutput { $script:result = Confirm-Proceed -Action 'delete the branch' }

# Assert
Assert-That -Condition (-not $script:result) -Message "A short 'y' does not proceed - only the full word does"
Assert-That -Condition (($lines -join "`n") -like '*Aborted by user*') -Message 'A declined answer warns that the run was aborted'

exit (Complete-TestRun)
