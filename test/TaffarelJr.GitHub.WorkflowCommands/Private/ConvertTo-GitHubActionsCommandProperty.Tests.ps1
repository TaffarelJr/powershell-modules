#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/ConvertTo-GitHubActionsCommandData.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/ConvertTo-GitHubActionsCommandProperty.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - plain text passes through unchanged
Assert-Equal -Expected 'plain text' -Actual (ConvertTo-GitHubActionsCommandProperty -Value 'plain text') `
    -Message 'Text with nothing to escape is unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - : and , are escaped on top of the data-segment set
Assert-Equal -Expected 'C%3A\build' -Actual (ConvertTo-GitHubActionsCommandProperty -Value 'C:\build') `
    -Message 'Colon is escaped to %3A'
Assert-Equal -Expected 'a%2Cb' -Actual (ConvertTo-GitHubActionsCommandProperty -Value 'a,b') `
    -Message 'Comma is escaped to %2C'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the inherited data-segment escapes still apply
Assert-Equal -Expected '100%25' -Actual (ConvertTo-GitHubActionsCommandProperty -Value '100%') `
    -Message 'Percent is still escaped to %25'
Assert-Equal -Expected 'a%0Ab' -Actual (ConvertTo-GitHubActionsCommandProperty -Value "a`nb") `
    -Message 'Line feed is still escaped to %0A'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every escaped character together
Assert-Equal -Expected 'file%3Aname%2C v1%25%0D%0A' `
    -Actual (ConvertTo-GitHubActionsCommandProperty -Value "file:name, v1%`r`n") `
    -Message 'All five escapes apply together without double-escaping'

exit (Complete-TestRun)
