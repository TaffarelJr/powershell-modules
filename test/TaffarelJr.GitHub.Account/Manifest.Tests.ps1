#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifestPath = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1'
$module = Import-Module $manifestPath -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$publicFolder = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/Public'
$publicFiles = @((Get-ChildItem -LiteralPath $publicFolder -Filter *.ps1).BaseName | Sort-Object)

# Act
$exported = @($module.ExportedFunctions.Keys | Sort-Object)

# Assert
Assert-Equal -Expected $publicFiles -Actual $exported -Message 'The module exports exactly one function per Public file'
Assert-Equal -Expected $publicFiles -Actual @($manifest.FunctionsToExport | Sort-Object) `
    -Message 'and the manifest lists exactly those'

#───────────────────────────────────────────────────────────────────────────────
# Act
$simple = @($module.ExportedFunctions.Values | Where-Object { -not $_.CmdletBinding } | ForEach-Object Name)

# Assert
Assert-Equal -Expected @() -Actual $simple `
    -Message 'Every exported function is an advanced function, so a stray or misspelled argument throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$privateFolder = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/Private'
$privateNames = @((Get-ChildItem -LiteralPath $privateFolder -Filter *.ps1).BaseName | Sort-Object)

# Act
$simplePrivate = @(& $module {
        param($Names)
        Get-Command -Name $Names -CommandType Function | Where-Object { -not $_.CmdletBinding } | ForEach-Object Name
    } $privateNames)

# Assert
Assert-That -Condition ($privateNames -contains 'Assert-GitHubAccountName') `
    -Message 'Precondition: the private functions were found'
Assert-Equal -Expected @() -Actual $simplePrivate -Message 'and every private function is an advanced function too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a misspelled -Hostname, which a simple function would drop, handing back the default host's token
$fake = New-FakeGitHubCli -Output @('gho_default_host')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubToken -Hostnme 'ghe.example'
    } -MessageLike "*parameter cannot be found*'Hostnme'*" `
        -Message 'A misspelled parameter is refused rather than ignored'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never asked'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$unhelped = @($exported.Where({ (Get-Help $_).Synopsis -cnotmatch '^[A-Z][a-z]+s ' }))

# Assert
Assert-Equal -Expected @() -Actual $unhelped `
    -Message 'Every exported function has comment-based help with a third-person synopsis'

exit (Complete-TestRun)
