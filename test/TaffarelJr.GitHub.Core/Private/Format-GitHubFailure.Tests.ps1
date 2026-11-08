#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

$format = {
    param([string]$Subject, [hashtable]$Result)
    Format-GitHubFailure -Subject $Subject -Result $Result
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - failures with and without a status, and one that printed nothing
$cases = @(
    @{
        Result = @{ Ok = $false; ExitCode = 1; Message = 'gh: Bad credentials (HTTP 401)' }
        Expected = "Probing x failed (HTTP 401):`ngh: Bad credentials (HTTP 401)"
        Message = 'A status gh reported is named, with gh''s output below'
    }
    @{
        Result = @{
            Ok = $false
            ExitCode = 4
            Message = "  To get started with GitHub CLI`r`nplease run: gh auth login  "
        }
        Expected = "Probing x failed (exit 4):`nTo get started with GitHub CLI`nplease run: gh auth login"
        Message = 'Without one, the exit code is, and the output is trimmed with its lines kept'
    }
    @{
        Result = @{ Ok = $false; ExitCode = 7; Message = $null }
        Expected = 'Probing x failed (exit 7): gh printed nothing.'
        Message = 'A failure that printed nothing says so'
    }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (& $module $format 'Probing x failed' $case.Result) `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a credential in the subject and on two lines of gh's output, with an
# e-mail address on a line after a colon
$result = @{
    Ok = $false
    ExitCode = 1
    Message = "Get `"https://u:SENTINEL@h.example/x`": EOF`nmail: me@example.com`nHTTP 502: Bad Gateway"
}

# Act
$message = & $module $format 'Probing https://v:SENTINEL@h.example/x failed' $result

# Assert
Assert-Equal -Expected (
    "Probing https://***@h.example/x failed (HTTP 502):`nGet `"https://***@h.example/x`": EOF`n" +
    "***@example.com`nHTTP 502: Bad Gateway"
) -Actual $message -Message 'Every credential is hidden, each line on its own, so one line cannot hide another'

exit (Complete-TestRun)
