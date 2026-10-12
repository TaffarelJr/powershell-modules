#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - message only, no properties
$lines = Get-HostOutput { Write-GitHubActionsNotice 'deprecated input ignored' }

# Assert
Assert-Equal -Expected '::notice::deprecated input ignored' -Actual $lines[0] -Message 'With no properties, no space or property list appears before the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - every property set
$full = Get-HostOutput {
    Write-GitHubActionsNotice -Message 'missing trailing newline' -File 'build.ps1' -Line 10 -EndLine 12 -Col 1 -EndColumn 5 -Title 'Style'
}

# Assert
Assert-Equal -Expected '::notice file=build.ps1,line=10,endLine=12,col=1,endColumn=5,title=Style::missing trailing newline' -Actual $full[0] `
    -Message 'Every property is rendered, in order, ahead of the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - only some properties set; the rest are left out entirely
$partial = Get-HostOutput { Write-GitHubActionsNotice -Message 'x' -File 'a.ps1' -Title 'Note' }

# Assert
Assert-Equal -Expected '::notice file=a.ps1,title=Note::x' -Actual $partial[0] -Message 'Properties left unset do not appear as empty key=value pairs'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a property value needing escaping
$escapedProp = Get-HostOutput { Write-GitHubActionsNotice -Message 'x' -Title 'a:b,c' }

# Assert
Assert-Equal -Expected '::notice title=a%3Ab%2Cc::x' -Actual $escapedProp[0] -Message 'A property value is escaped with the property rules, not the data rules'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = Get-HostOutput { 'one', 'two' | Write-GitHubActionsNotice }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two strings prints two separate lines'

exit (Complete-TestRun)
