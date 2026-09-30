#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange / Act - a step is rendered as a header: rule, text, rule
$lines = Get-HostOutput { Write-Step 'Build' }

# Assert
Assert-Equal -Expected 3 -Actual $lines.Count -Message 'Write-Step renders as a three-line header'
Assert-That -Condition ($lines[1] -like '*Step 1: Build*') -Message 'The first step is numbered 1'

# Arrange / Act - the number auto-increments; the caller never tracks it
$second = Get-HostOutput { Write-Step 'Test' }

# Assert
Assert-That -Condition ($second[1] -like '*Step 2: Test*') -Message 'A second call auto-increments to step 2'

# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'A', 'B' | Write-Step }

# Assert
Assert-Equal -Expected 6 -Actual $piped.Count -Message 'Piping two titles renders two separate three-line headers'

exit (Complete-TestRun)
