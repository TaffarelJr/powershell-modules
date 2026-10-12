#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected 'Workflow run 7 was still queued after 30 s. Give a longer -TimeoutSeconds to wait more.' `
    -Actual (Get-GitHubTimeoutMessage -Subject 'Workflow run 7 was still queued after 30 s.') `
    -Message 'The subject is followed by the advice'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a subject naming a repository by a URL with a token
$subject = 'Run 7 of https://u:SENTINEL@ghe.example.com/o/r was still queued after 30 s.'

# Act
$message = Get-GitHubTimeoutMessage -Subject $subject

# Assert
Assert-Equal -Expected (
    'Run 7 of https://***@ghe.example.com/o/r was still queued after 30 s.' +
    ' Give a longer -TimeoutSeconds to wait more.'
) -Actual $message -Message 'The credential a URL in the subject carries is hidden'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - names after the subject
Assert-Equal -Expected 'Checks were still pending: build, lint. Give a longer -TimeoutSeconds to wait more.' `
    -Actual (Get-GitHubTimeoutMessage -Subject 'Checks were still pending:' -Detail 'build', 'lint') `
    -Message 'The names follow the subject, joined with commas and ended with a full stop'
Assert-Equal -Expected 'Checks were still pending: build. Give a longer -TimeoutSeconds to wait more.' `
    -Actual (Get-GitHubTimeoutMessage -Subject 'Checks were still pending:' -Detail 'build') `
    -Message 'one name the same'
Assert-Equal -Expected 'Nothing came. Give a longer -TimeoutSeconds to wait more.' `
    -Actual (Get-GitHubTimeoutMessage -Subject 'Nothing came.' -Detail @()) `
    -Message 'and no names leave the subject as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names with an @, one of them after a colon, and one holding a URL credential
$names = @('build (node@18)', 'ci: lint@2', 'deploy https://u:SENTINEL@ghe.example.com/o/r')

# Act
$message = Get-GitHubTimeoutMessage -Subject 'Checks were still pending:' -Detail $names

# Assert
Assert-Equal -Expected (
    'Checks were still pending: build (node@18), ***@2, deploy https://***@ghe.example.com/o/r.' +
    ' Give a longer -TimeoutSeconds to wait more.'
) -Actual $message -Message 'Each name is hidden on its own: the sentence before them and the other names are kept'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - the last failure is not part of the message any more
Assert-Throws -ScriptBlock {
    Get-GitHubTimeoutMessage -Subject 'x.' -LastFailure 'HTTP 502: Bad Gateway'
} -MessageLike "*A parameter cannot be found that matches parameter name 'LastFailure'*" `
    -Message 'No last failure is taken: a failed read ends a wait before its deadline'

exit (Complete-TestRun)
