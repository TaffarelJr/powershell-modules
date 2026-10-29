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

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a cache, and the reference each gives
$forms = @(
    @{ Given = '1234'; Expected = '1234'; Message = 'An id written as text is returned as it is' }
    @{ Given = [long]5000000001; Expected = '5000000001'; Message = 'A number is returned as its text' }
    @{ Given = 'npm-abc'; Expected = 'npm-abc'; Message = 'A key is returned as it is' }
    @{ Given = ' key with spaces '; Expected = ' key with spaces '; Message = 'with its spaces, which a key may hold' }
    @{
        Given    = [PSCustomObject]@{ Id = [long]5000000001; Key = 'npm-abc' }
        Expected = '5000000001'
        Message  = 'A cache object is read by its Id'
    }
    @{ Given = @{ Id = 5; Key = 'a' }; Expected = '5'; Message = 'A hashtable is read by its Id key' }
    @{ Given = [ordered]@{ ID = 'npm-abc'; KEY = 'a' }; Expected = 'npm-abc'; Message = 'in any case' }
    @{
        Given    = [ordered]@{ Keys = 'k'; Id = 7; Key = 'a' }
        Expected = '7'
        Message  = 'and one holding a Keys entry is read all the same'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $reference = & $module { param($c) ConvertTo-GitHubCacheReference -Cache $c } $form.Given
    Assert-Equal -Expected $form.Expected -Actual $reference -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no cache, and why each is refused
$lacking = 'A cache object needs an Id and a Key, as Get-GitHubCache gives, and this one lacks one:'
$refused = @(
    @{
        Given   = '   '
        Message = 'Blank text is refused'
        Pattern = "'   ' is not a cache: give its id or key, or a cache object."
    }
    @{
        Given   = [PSCustomObject]@{ Key = 'npm-abc' }
        Message = 'An object with no Id is refused'
        Pattern = "$lacking PSCustomObject."
    }
    @{
        Given   = [PSCustomObject]@{ Id = $null; Key = 'npm-abc' }
        Message = 'as is one whose Id is $null'
        Pattern = "$lacking PSCustomObject."
    }
    @{
        Given   = [PSCustomObject]@{ Id = 4242; Name = 'CI'; Path = '.github/workflows/ci.yml' }
        Message = 'A workflow, whose Id is no cache''s, is refused for having no Key'
        Pattern = "$lacking PSCustomObject."
    }
    @{
        Given   = [PSCustomObject]@{ Id = 4242; DatabaseId = 77; Status = 'completed' }
        Message = 'as is any other object with an Id'
        Pattern = "$lacking PSCustomObject."
    }
    @{
        Given   = @{ Key = 'npm-abc' }
        Message = 'and a hashtable with no Id key'
        Pattern = "$lacking Hashtable."
    }
    @{
        Given   = @{ Id = 5 }
        Message = 'or no Key key'
        Pattern = "$lacking Hashtable."
    }
    @{
        Given   = @{ Id = ' '; Key = 'a' }
        Message = 'or a blank Id'
        Pattern = "$lacking Hashtable."
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module { param($c) ConvertTo-GitHubCacheReference -Cache $c } $case.Given
    } -MessageLike $case.Pattern -Message $case.Message
}

exit (Complete-TestRun)
