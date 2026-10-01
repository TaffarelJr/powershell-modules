#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - shadow Read-Host so no test here waits on a real person
$global:confirmAnswers = [System.Collections.Generic.Queue[string]]::new()
function global:Read-Host {
    param(
        [Parameter(Position = 0)]
        [string]$Prompt,
        [switch]$AsSecureString
    )
    return $global:confirmAnswers.Dequeue()
}

# Arrange / Act / Assert - the full word, and the short form, both answer yes
$global:confirmAnswers.Enqueue('y')
Assert-That -Condition (Confirm-Input -Prompt 'Proceed?') -Message "'y' answers yes"

$global:confirmAnswers.Enqueue('yes')
Assert-That -Condition (Confirm-Input -Prompt 'Proceed?') -Message "'yes' answers yes"

$global:confirmAnswers.Enqueue('Y')
Assert-That -Condition (Confirm-Input -Prompt 'Proceed?') -Message 'A yes answer is case-insensitive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the short form and the full word both answer no
$global:confirmAnswers.Enqueue('n')
Assert-That -Condition (-not (Confirm-Input -Prompt 'Proceed?')) -Message "'n' answers no"

$global:confirmAnswers.Enqueue('no')
Assert-That -Condition (-not (Confirm-Input -Prompt 'Proceed?')) -Message "'no' answers no"

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a bare Enter accepts -Default
$global:confirmAnswers.Enqueue('')
Assert-That -Condition (Confirm-Input -Prompt 'Proceed?' -Default) -Message 'A bare Enter accepts -Default when it defaults to yes'

$global:confirmAnswers.Enqueue('')
Assert-That -Condition (-not (Confirm-Input -Prompt 'Proceed?')) -Message 'A bare Enter defaults to no without -Default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an unrecognized answer re-asks instead of failing the run
$global:confirmAnswers.Enqueue('maybe')
$global:confirmAnswers.Enqueue('y')
$lines = Get-HostOutput { $script:retryResult = Confirm-Input -Prompt 'Proceed?' }

# Assert
Assert-That -Condition $script:retryResult -Message 'The eventual valid answer is returned after a bad one'
Assert-That -Condition ($lines.Count -ge 1) -Message 'The bad answer warns before re-asking'

exit (Complete-TestRun)
