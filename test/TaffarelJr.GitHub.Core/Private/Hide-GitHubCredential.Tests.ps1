#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

$hide = {
    param([string]$Text)
    Hide-GitHubCredential -Text $Text
}

$classic = 'A' * 36
$fine = 'B' * 22 + '_' + 'c' * 59

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every form of GitHub token, on its own and in a line gh printed
$cases = @(
    @{ Text = "ghp_$classic"; Expected = '***'; Name = 'A personal access token is hidden' }
    @{ Text = "gho_$classic"; Expected = '***'; Name = 'and an OAuth token' }
    @{ Text = "ghu_$classic"; Expected = '***'; Name = 'and a user-to-server token' }
    @{ Text = "ghs_$classic"; Expected = '***'; Name = 'and a server-to-server token' }
    @{ Text = "ghr_$classic"; Expected = '***'; Name = 'and a refresh token' }
    @{ Text = "github_pat_$fine"; Expected = '***'; Name = 'and a fine-grained token, underscores and all' }
    @{
        Text = "  - Token: gho_$classic"
        Expected = '  - Token: ***'
        Name = 'A token in a printed line is hidden, the words around it kept'
    }
    @{
        Text = "a=ghp_$classic,b=ghs_$classic"
        Expected = 'a=***,b=***'
        Name = 'and so is each of two tokens in one line'
    }
    @{
        Text = "https://x-access-token:ghs_$classic@github.com/o/r"
        Expected = 'https://***@github.com/o/r'
        Name = 'A token in a URL is hidden with the URL''s own user information'
    }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (& $module $hide $case.Text) -Message $case.Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that only looks like a token, or is not one
$kept = @(
    @{ Text = 'gho_***********************************'; Name = 'The masked token gh prints by default is kept' }
    @{ Text = 'ghp_short'; Name = 'A prefix with too little after it is kept' }
    @{ Text = "xghp_$classic"; Name = 'a token inside a longer word is kept' }
    @{ Text = "GHP_$classic"; Name = 'a token in another case is kept' }
    @{ Text = 'Reading gist abc123 failed'; Name = 'and a line with no credential is kept as it is' }
    @{ Text = ''; Name = 'and an empty line' }
)

# Act / Assert
foreach ($case in $kept) {
    Assert-Equal -Expected $case.Text -Actual (& $module $hide $case.Text) -Message $case.Name
}

#───────────────────────────────────────────────────────────────────────────────
# Act - several lines piped in
$lines = & $module {
    param($One, $Two)
    @($One, 'plain line', $Two) | Hide-GitHubCredential
} "token ghp_$classic" "see https://u:SENTINEL@h.example/o/r"

# Assert
Assert-Equal -Expected @('token ***', 'plain line', 'see https://***@h.example/o/r') -Actual @($lines) `
    -Message 'Piped lines are each hidden on their own, one string out for each'

exit (Complete-TestRun)
