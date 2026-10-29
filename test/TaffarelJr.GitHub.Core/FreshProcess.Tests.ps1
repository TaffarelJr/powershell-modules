#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot 'GitHubCoreTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new pwsh that imports only this module (and the one it requires),
# so an assembly a type literal names may not be loaded yet, as in a user's
# own first session; the test suite's processes have long loaded everything.
$quote = { param($Path) "'" + $Path.Replace("'", "''") + "'" }
$processInvocation = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
$core = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1'
$script = @"
`$names = [AppDomain]::CurrentDomain.GetAssemblies().GetName().Name
"json loaded: `$(`$names -contains 'System.Text.Json')"
Import-Module $(& $quote $processInvocation)
Import-Module $(& $quote $core)
`$json = ConvertFrom-GitHubJson -Line '{"a_b":1,"createdAt":"2024-01-02T03:04:05Z","files":{"x_y":2}}' -KeepKeysOf files
"`$(`$json.AB) `$(`$json.CreatedAt.Kind) `$(@(`$json.Files.PSBase.Keys) -join ',')"
(ConvertTo-PascalCaseObject -InputObject @{ html_url = 'u' }).HtmlUrl
Hide-UrlCredential -Text 'https://u:SENTINEL@github.com/o/r'
Test-GitHubPollExpired -Poll (New-GitHubPoll -TimeoutSeconds 60 -PollSeconds 5)
Assert-GitHubHostname -Hostname 'bücher.example'
ConvertTo-GitHubRepositoryReference -Repository 'o/r.git'
"@
$work = New-CoreTestFolder
$scriptPath = Join-Path $work 'fresh.ps1'
$outputPath = Join-Path $work 'fresh.out'
$errorPath = Join-Path $work 'fresh.err'
[System.IO.File]::WriteAllText($scriptPath, $script, [System.Text.UTF8Encoding]::new($false))
# A new pwsh often loads System.Text.Json in the background while it starts, so
# the case is tried a few times before it is skipped.
try {
    # Act
    foreach ($attempt in 1..5) {
        $start = @{
            FilePath               = (Get-Process -Id $PID).Path
            ArgumentList           = @('-NoProfile', '-NonInteractive', '-File', "`"$scriptPath`"")
            NoNewWindow            = $true
            PassThru               = $true
            RedirectStandardOutput = $outputPath
            RedirectStandardError  = $errorPath
        }
        $child = Start-Process @start
        $exited = $child.WaitForExit(120000)
        if (-not $exited) {
            Stop-Process -Id $child.Id -Force
        }

        $lines = @(Get-Content -LiteralPath $outputPath -Encoding utf8)
        $errors = [System.IO.File]::ReadAllText($errorPath)
        if ($lines.Count -eq 0 -or $lines[0] -ne 'json loaded: True') {
            break
        }
    }

    if ($lines.Count -gt 0 -and $lines[0] -eq 'json loaded: True') {
        exit (Skip-TestRun -Reason 'Every new pwsh had already loaded System.Text.Json, so the case could not be set up.')
    }

    # Assert
    Assert-Equal -Expected @($true, 0, '') -Actual @($exited, $child.ExitCode, $errors) `
        -Message 'A new pwsh runs the module''s own work and exits, writing no error'
    Assert-Equal -Expected @(
        'json loaded: False'
        '1 Utc x_y'
        'u'
        'https://***@github.com/o/r'
        'False'
        'True'
        'o/r'
    ) -Actual $lines `
        -Message ('with System.Text.Json not loaded before the module is: JSON, re-casing, credential hiding,' +
            ' the poll clock, the host rule, and references all work')
}
finally {
    Remove-CoreTestFolder -Path $work
}

exit (Complete-TestRun)
