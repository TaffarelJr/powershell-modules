#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange / Act
$lines = Get-HostOutput { Write-Success 'built the project' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Write-Success prints exactly one line'
Assert-That -Condition ($lines[0] -like '*✅*') -Message 'The line carries the success marker'
Assert-That -Condition ($lines[0] -like '*built the project*') -Message 'The line carries the given text'

# Arrange / Act - blank text
$blank = Get-HostOutput { Write-Success '   ' }

# Assert
Assert-That -Condition ($blank[0] -like '*(no message)*') -Message 'Blank text renders the placeholder instead of an empty line'

# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'first', 'second' | Write-Success }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'
Assert-That -Condition ($piped[0] -like '*first*') -Message 'The first piped line carries "first"'
Assert-That -Condition ($piped[1] -like '*second*') -Message 'The second piped line carries "second"'

# Arrange / Act - -Indent overrides the ambient indent
$overridden = Get-HostOutput { Write-Success -Text 'x' -Indent 4 }
$leadingSpaces = ([regex]::Match($overridden[0], '^ *')).Length

# Assert
Assert-Equal -Expected 6 -Actual $leadingSpaces -Message '-Indent 4 adds four spaces on top of the two-space base'

# Arrange - ambient indent from Push-Indent applies without an explicit -Indent
Push-Indent -Width 3
$ambient = Get-HostOutput { Write-Success 'y' }
Pop-Indent
$ambientLeadingSpaces = ([regex]::Match($ambient[0], '^ *')).Length

# Assert
Assert-Equal -Expected 5 -Actual $ambientLeadingSpaces -Message 'Ambient indent from Push-Indent applies automatically'

exit (Complete-TestRun)
