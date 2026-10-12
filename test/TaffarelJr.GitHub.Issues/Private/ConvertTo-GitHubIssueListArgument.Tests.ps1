#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act - names, one holding a comma and one a quote
$arguments = @(& $module { ConvertTo-GitHubIssueListArgument -Name 'Label' -Flag '--label' -Value 'bug', 'a, b', 'say "hi"' })

# Assert
$expected = @('--label=bug', '--label="a, b"', '--label="say ""hi"""')
Assert-Equal -Expected $expected -Actual $arguments -Message 'Each name becomes one flag, as a CSV field'

#───────────────────────────────────────────────────────────────────────────────
# Act - no names at all
$none = @(& $module { ConvertTo-GitHubIssueListArgument -Name 'Label' -Flag '--label' -Value @() })
$missing = @(& $module { ConvertTo-GitHubIssueListArgument -Name 'Label' -Flag '--label' })

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'An empty list gives no flag'
Assert-Equal -Expected 0 -Actual $missing.Count -Message 'and so does a list left out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - lists holding a name that names nothing
$refused = @(
    @{ Value = @('bug', ''); Message = 'An empty name is refused' }
    @{ Value = @(" `t"); Message = 'as is one of white space alone' }
    @{ Value = @('bug', $null); Message = 'and a $null among the names' }
)
foreach ($case in $refused) {
    $value = $case.Value

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($v) ConvertTo-GitHubIssueListArgument -Name 'AddLabel' -Flag '--add-label' -Value $v } $value
    } -MessageLike '-AddLabel has a blank element, which would send --add-label= with nothing after it. Give names, or leave -AddLabel out.' `
        -Message $case.Message
}

exit (Complete-TestRun)
