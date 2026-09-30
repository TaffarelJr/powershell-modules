#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - closes an open Doing line with the default wording
$lines = Get-HostOutput { Write-Doing 'building'; Write-Done }

# Assert
Assert-Equal -Expected 2 -Actual $lines.Count -Message 'Write-Doing plus Write-Done together print two records'
Assert-That -Condition ($lines[1] -like '* done*') -Message 'Write-Done closes the line with "done" by default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Skip closes it as "already done" instead
$skipped = Get-HostOutput { Write-Doing 'building'; Write-Done -Skip }

# Assert
Assert-That -Condition ($skipped[1] -like '*already done*') -Message '-Skip closes the line as "already done"'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a custom -Text overrides the default wording
$custom = Get-HostOutput { Write-Doing 'building'; Write-Done -Text 'up to date' }

# Assert
Assert-That -Condition ($custom[1] -like '*up to date*') -Message 'A custom -Text replaces the default outcome wording'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - calling Write-Done with no open Write-Doing
# falls back to a fresh Write-Success/Write-Skip line
# instead of a bare continuation
$fresh = Get-HostOutput { Write-Done }

# Assert
Assert-Equal -Expected 1 -Actual $fresh.Count -Message 'Write-Done with nothing open prints one fresh line'
Assert-That -Condition ($fresh[0] -like '*✅*done*') -Message 'The fallback line uses the success marker and wording'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the fallback respects -Skip too
$freshSkipped = Get-HostOutput { Write-Done -Skip }

# Assert
Assert-That -Condition ($freshSkipped[0] -like '*⏭️*already done*') -Message 'The fallback with -Skip uses the skip marker and wording'

exit (Complete-TestRun)
