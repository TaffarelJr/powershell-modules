using namespace System.IO

function New-FakeGitHubCli {
    <#
    .SYNOPSIS
        Puts a fake gh ahead of the real one on PATH that records every
        call and answers each with the same canned output and exit code.
    .DESCRIPTION
        Not exported - a test-only fixture, shared across this module's
        test files rather than reimplemented per file.

        The fake is a gh.ps1 script. PowerShell resolves a .ps1 on PATH
        ahead of an .exe further down it and runs it in-process, so the
        module's real invocation path - ProcessInvocation splatting the
        argument array and piping -StdIn - is exactly what gets exercised,
        with no seam inside the module. Piped input reaches a .ps1 as
        $input, and its exit sets $LASTEXITCODE, as a native gh's would.
    .PARAMETER Output
        The lines the fake prints, whatever it is asked.
    .PARAMETER ExitCode
        The exit code the fake returns, whatever it is asked.
    .OUTPUTS
        A fixture object (Path, CallLog, OriginalPath) for
        Get-FakeGitHubCall and Remove-FakeGitHubCli.
    #>
    param(
        [string[]]$Output = @(),

        [int]$ExitCode = 0
    )

    $path = Join-Path ([Path]::GetTempPath()) "gh-fake-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null

    $callLog = Join-Path $path 'calls.jsonl'
    $outputFile = Join-Path $path 'output.txt'
    [File]::WriteAllLines($outputFile, [string[]]$Output)

    $fake = @(
        '$call = [PSCustomObject]@{ Arguments = @($args); StdIn = (@($input) -join "`n") }'
        "Add-Content -LiteralPath '$callLog' -Value (`$call | ConvertTo-Json -Compress)"
        "Get-Content -LiteralPath '$outputFile'"
        "exit $ExitCode"
    )
    Set-Content -LiteralPath (Join-Path $path 'gh.ps1') -Value $fake

    $fixture = [PSCustomObject]@{
        Path         = $path
        CallLog      = $callLog
        OriginalPath = $env:PATH
    }
    $env:PATH = "$path$([Path]::PathSeparator)$env:PATH"

    return $fixture
}

function Get-FakeGitHubCall {
    <#
    .SYNOPSIS
        Returns every call the fake gh has recorded, oldest first.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Fixture
        The object New-FakeGitHubCli returned.
    .OUTPUTS
        One object per call (Arguments, StdIn), always an array.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    if (-not (Test-Path -LiteralPath $Fixture.CallLog)) {
        return , @()
    }

    $calls = @(Get-Content -LiteralPath $Fixture.CallLog | ForEach-Object { $_ | ConvertFrom-Json })
    foreach ($call in $calls) {
        $call.Arguments = @($call.Arguments)
    }

    return , $calls
}

function Remove-FakeGitHubCli {
    <#
    .SYNOPSIS
        Takes the fake gh back off PATH and deletes it.
    .DESCRIPTION
        Not exported - a test-only fixture. Tolerates a folder that is
        already gone, so a test's own finally block never fails on
        cleanup it does not strictly need.
    .PARAMETER Fixture
        The object New-FakeGitHubCli returned.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $env:PATH = $Fixture.OriginalPath
    if (Test-Path -LiteralPath $Fixture.Path) {
        Remove-Item -LiteralPath $Fixture.Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-LiveGitHub {
    <#
    .SYNOPSIS
        Reports whether the real gh is authenticated, so a live test can
        skip cleanly where it is not.
    .DESCRIPTION
        Not exported - a test-only fixture. A live test exercises the real
        gh against a public repository to confirm the --json field names a
        function requests actually exist; where gh has no login and no
        GH_TOKEN, the file prints that it skipped and exits with an empty
        tally instead of failing.
    .OUTPUTS
        $true when gh reports an active, working login.
    #>
    $status = Invoke-NativeRead -Command 'gh' -Arguments @('auth', 'status', '--active')
    return $status.Ok
}
