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

$assert = {
    param([string]$Name, [bool]$AllowBlank)

    Assert-GitHubOrganizationName -Name $Name -AllowBlank:$AllowBlank
}
$rule = 'is not an organization name: give letters, digits, and dashes.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names GitHub accepts
$accepted = @('org', 'my-org', 'Org1', '9lives', 'a')

# Act / Assert
foreach ($name in $accepted) {
    Assert-Equal -Expected $true -Actual (& $module $assert $name $false) -Message "'$name' passes"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a name
$refused = @(
    @{ Name = ''; Message = 'An empty value is refused' }
    @{ Name = ' '; Message = 'and so is a blank one' }
    @{ Name = '-x'; Message = 'and one starting with a dash' }
    @{ Name = 'o_rg'; Message = 'and one with an underscore' }
    @{ Name = 'org/rulesets/9'; Message = 'and one with a slash' }
)

# Act / Assert
foreach ($case in $refused) {
    $like = [WildcardPattern]::Escape("'$($case.Name)' $rule")
    Assert-Throws -ScriptBlock { & $module $assert $case.Name $false } -MessageLike $like -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a URL that carries a credential, given where a name belongs
$url = 'https://user:SENTINEL@github.com/org'
$like = [WildcardPattern]::Escape("'https://***@github.com/org' $rule")

# Act / Assert
Assert-Throws -ScriptBlock { & $module $assert $url $false } -MessageLike $like `
    -Message 'A URL is refused and shown without the credential it carried'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a caller that refuses a blank value in a message of its own
$blanks = @(
    @{ Name = ''; Message = 'An empty value passes with -AllowBlank' }
    @{ Name = ' '; Message = 'as does a space' }
    @{ Name = "`t"; Message = 'and a tab' }
)

# Act / Assert
foreach ($case in $blanks) {
    Assert-Equal -Expected $true -Actual (& $module $assert $case.Name $true) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$like = [WildcardPattern]::Escape("'-x' $rule")

# Act / Assert
Assert-Throws -ScriptBlock { & $module $assert '-x' $true } -MessageLike $like `
    -Message '-AllowBlank still refuses a value that is not blank and not a name'

exit (Complete-TestRun)
