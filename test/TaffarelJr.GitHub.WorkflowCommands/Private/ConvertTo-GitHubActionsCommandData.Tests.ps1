#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/ConvertTo-GitHubActionsCommandData.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - plain text passes through unchanged
Assert-Equal -Expected 'plain text' -Actual (ConvertTo-GitHubActionsCommandData -Value 'plain text') -Message 'Text with nothing to escape is unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - % is escaped first, so it never doubles up
# with the percent CR/LF escaping introduces
Assert-Equal -Expected '100%25' -Actual (ConvertTo-GitHubActionsCommandData -Value '100%') -Message 'Percent is escaped to %25'
Assert-Equal -Expected 'a%0Db' -Actual (ConvertTo-GitHubActionsCommandData -Value "a`rb") -Message 'Carriage return is escaped to %0D'
Assert-Equal -Expected 'a%0Ab' -Actual (ConvertTo-GitHubActionsCommandData -Value "a`nb") -Message 'Line feed is escaped to %0A'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every escaped character together, in the order
# a careless implementation would double-escape them
Assert-Equal -Expected 'a%25%0D%0A' -Actual (ConvertTo-GitHubActionsCommandData -Value "a%`r`n") -Message 'Percent, CR, and LF together each escape exactly once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - : and , are left alone here; only
# ConvertTo-GitHubActionsCommandProperty escapes those
Assert-Equal -Expected 'a:b,c' -Actual (ConvertTo-GitHubActionsCommandData -Value 'a:b,c') -Message 'Colon and comma are not data-segment characters'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an empty string is allowed and stays empty
Assert-Equal -Expected '' -Actual (ConvertTo-GitHubActionsCommandData -Value '') -Message 'An empty string is allowed and returned unchanged'

exit (Complete-TestRun)
