#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') `
    -Force `
    -PassThru

$convert = {
    param($Branch)

    ConvertTo-GitHubBranchName -Branch $Branch
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a branch, and the name each gives
$forms = @(
    @{ Given = 'main'; Expected = 'main'; Message = 'Text is the branch''s name' }
    @{ Given = 'feature/x y'; Expected = 'feature/x y'; Message = 'and is kept as it is, a slash or a space included' }
    @{ Given = 7; Expected = '7'; Message = 'A number is the name it spells' }
    @{
        Given    = [PSCustomObject]@{ Name = 'release'; Protected = $true }
        Expected = 'release'
        Message  = 'An object is read by its Name'
    }
    @{
        Given    = [PSCustomObject]@{ Name = 7 }
        Expected = '7'
        Message  = 'one with a numeric Name by that number, not its text'
    }
    @{ Given = @{ Name = 'hot' }; Expected = 'hot'; Message = 'A hashtable by its Name' }
    @{ Given = @{ name = 'lower' }; Expected = 'lower'; Message = 'in any case of the key' }
    @{
        Given    = @{ Name = 'kept'; Keys = 'x'; Count = 3 }
        Expected = 'kept'
        Message  = 'even when it holds Keys and Count entries'
    }
    @{ Given = [ordered]@{ Name = 'sorted' }; Expected = 'sorted'; Message = 'and an ordered one the same' }
)

# Act / Assert
foreach ($form in $forms) {
    $name = & $module $convert $form.Given
    Assert-Equal -Expected $form.Expected -Actual $name -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no branch, and what each is refused with
$blank = "-Branch is blank: give the branch's name."
$refusals = @(
    @{ Given = ''; Expected = $blank; Message = 'An empty name' }
    @{ Given = " `t"; Expected = $blank; Message = 'A blank name' }
    @{ Given = @{ Name = ' ' }; Expected = $blank; Message = 'A hashtable with a blank Name' }
    @{ Given = @{ Name = $null }; Expected = $blank; Message = 'one with a $null Name' }
    @{
        Given    = [PSCustomObject]@{ Id = 1 }
        Expected = 'A branch object needs a Name, and this one has none: PSCustomObject.'
        Message  = 'An object without a Name'
    }
    @{
        Given    = @{ Id = 1 }
        Expected = 'A branch object needs a Name, and this one has none: Hashtable.'
        Message  = 'A hashtable without a Name'
    }
    @{
        Given    = [PSCustomObject]@{ Name = @('a', 'b') }
        Expected = "A branch object's Name must be text, and this one's is Object[]."
        Message  = 'An object whose Name is a list'
    }
    @{
        Given    = @('a', 'b')
        Expected = 'Give one branch at a time, not a list of 2; pipe them to name several.'
        Message  = 'A list of names'
    }
    @{
        Given    = @()
        Expected = 'Give one branch at a time, not a list of 0; pipe them to name several.'
        Message  = 'An empty list'
    }
    @{
        Given    = $true
        Expected = "'True' is not a branch name: give the branch's name, or a branch object."
        Message  = 'A bool'
    }
)

# Act / Assert
foreach ($refusal in $refusals) {
    Assert-Throws -ScriptBlock { & $module $convert $refusal.Given } `
        -MessageLike ([WildcardPattern]::Escape($refusal.Expected)) -Message "$($refusal.Message) is refused"
}

exit (Complete-TestRun)
