#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act
$context = & $module { New-GitHubJsonContext -KeepFieldNames $true -KeepKeysOf 'files', 'inputs' }

# Assert
Assert-Equal -Expected @('DateKeys', 'Iso', 'KeepFieldNames', 'KeepKeysOf', 'Names', 'Reserved') `
    -Actual @($context.PSBase.Keys | Sort-Object) `
    -Message 'The context carries the settings and the caches'
Assert-Equal -Expected $true -Actual $context.KeepFieldNames -Message 'with -KeepFieldNames as given'
Assert-Equal -Expected @($true, $false) `
    -Actual @($context.KeepKeysOf.ContainsKey('files'), $context.KeepKeysOf.ContainsKey('Files')) `
    -Message 'Kept names are matched with their case'
Assert-Equal -Expected 0 -Actual ($context.Names.Count + $context.DateKeys.Count) -Message 'The name caches start empty'
Assert-Equal -Expected @($true, $true, $true, $false) `
    -Actual @(
        $context.Reserved.ContainsKey('psobject'), $context.Reserved.ContainsKey('PSTypeNames'),
        $context.Reserved.ContainsKey(''), $context.Reserved.ContainsKey('Count')
    ) `
    -Message 'Names a PSCustomObject cannot hold are listed, in any case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that is and is not an ISO 8601 timestamp
$iso = (& $module { New-GitHubJsonContext }).Iso
$cases = @(
    @{ Text = '2024-01-02T03:04:05Z'; Expected = $true; Message = 'A UTC timestamp matches' }
    @{ Text = '2024-01-02T03:04:05.1234567+05:00'; Expected = $true; Message = 'and one with a fraction and an offset' }
    @{ Text = '2024-01-02'; Expected = $false; Message = 'A date alone does not' }
    @{ Text = '2024-01-02T03:04:05'; Expected = $false; Message = 'nor a time with no zone' }
    @{ Text = 'x2024-01-02T03:04:05Z'; Expected = $false; Message = 'nor text around a timestamp' }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual $iso.IsMatch($case.Text) -Message $case.Message
}

exit (Complete-TestRun)
