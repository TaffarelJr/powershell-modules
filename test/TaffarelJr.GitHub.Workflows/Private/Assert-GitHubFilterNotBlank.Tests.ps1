#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru

$assert = {
    param($Bound)
    $dictionary = [System.Collections.Generic.Dictionary[string, object]]::new()
    foreach ($key in $Bound.PSBase.Keys) {
        $dictionary[$key] = $Bound[$key]
    }

    Assert-GitHubFilterNotBlank -BoundParameters $dictionary -Name 'Key', 'Ref'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters left out or given a value, and parameters not checked
$passing = @(
    @{ Bound = @{}; Message = 'Nothing given passes' }
    @{ Bound = @{ Key = 'npm'; Ref = 'refs/heads/main' }; Message = 'as do filters with values' }
    @{ Bound = @{ Sort = '' }; Message = 'and a blank parameter that is not one of the filters named' }
)

# Act / Assert
foreach ($case in $passing) {
    $output = @(& $module $assert $case.Bound)
    Assert-Equal -Expected 0 -Actual $output.Count -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters given blank
$refused = @(
    @{ Bound = @{ Key = '' }; Name = 'Key'; Message = 'An empty filter is refused' }
    @{ Bound = @{ Key = 'npm'; Ref = '  ' }; Name = 'Ref'; Message = 'as is a blank one, naming it' }
    @{ Bound = @{ Ref = $null }; Name = 'Ref'; Message = 'and $null' }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $assert $case.Bound
    } -MessageLike ("-$($case.Name) was given but is blank, so it would filter nothing." +
        " Give a value, or leave -$($case.Name) off.") `
        -Message $case.Message
}

exit (Complete-TestRun)
