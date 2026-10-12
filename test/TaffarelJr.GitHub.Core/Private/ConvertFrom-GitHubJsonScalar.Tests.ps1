#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Parses one JSON value and converts it.
$convert = {
    param([string]$Json)
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        ConvertFrom-GitHubJsonScalar -Element $document.RootElement
    }
    finally {
        $document.Dispose()
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - JSON values, and what each becomes
$cases = @(
    @{ Json = '"text"'; Expected = 'text'; Type = [string]; Message = 'A string is a string' }
    @{
        Json = '"2024-01-02T03:04:05Z"'
        Expected = '2024-01-02T03:04:05Z'
        Type = [string]
        Message = 'even one that looks like a timestamp'
    }
    @{ Json = '-12'; Expected = [long]-12; Type = [long]; Message = 'A whole number is a [long]' }
    @{ Json = '9223372036854775807'; Expected = [long]::MaxValue; Type = [long]; Message = 'up to the largest one' }
    @{
        Json = '9223372036854775808'
        Expected = 9223372036854775808D
        Type = [decimal]
        Message = 'and beyond that a [decimal], still exact'
    }
    @{ Json = '0.1'; Expected = 0.1D; Type = [decimal]; Message = 'A fraction is a [decimal], exactly as written' }
    @{
        Json = '1e20'
        Expected = 100000000000000000000D
        Type = [decimal]
        Message = 'and so is an exponent a [decimal] can hold'
    }
    @{ Json = '1e30'; Expected = 1e30; Type = [double]; Message = 'beyond that, a [double]' }
    @{ Json = '1e400'; Expected = '1e400'; Type = [string]; Message = 'and beyond a [double], the text the JSON had' }
    @{ Json = 'true'; Expected = $true; Type = [bool]; Message = 'true is $true' }
    @{ Json = 'false'; Expected = $false; Type = [bool]; Message = 'false is $false' }
)

# Act / Assert
foreach ($case in $cases) {
    $value = & $module $convert $case.Json
    Assert-Equal -Expected $case.Expected -Actual $value -Message $case.Message
    Assert-Equal -Expected $case.Type -Actual $value.GetType() -Message "($($case.Json) as $($case.Type.Name))"
}

#───────────────────────────────────────────────────────────────────────────────
# Act - null
$nothing = @(& $module $convert 'null')

# Assert
Assert-Equal -Expected 0 -Actual $nothing.Count -Message 'null writes nothing'

exit (Complete-TestRun)
