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
    param([string]$Name, [string]$Kind)

    Assert-GitHubSecretOrVariableName -Name $Name -Kind $Kind
}
$rule = 'give letters, digits, and _, not led by a digit or GITHUB_.'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names GitHub accepts
$accepted = @('A', 'NUGET_API_KEY', '_x', 'a1', 'GITHUBX')

# Act / Assert
foreach ($name in $accepted) {
    Assert-Equal -Expected $true -Actual (& $module $assert $name 'secret') -Message "'$name' passes as a secret's"
    Assert-Equal -Expected $true -Actual (& $module $assert $name 'variable') -Message "'$name' passes as a variable's"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a name, and the kind each is refused as
$refused = @(
    @{ Name = ''; Kind = 'secret'; Message = 'An empty value is refused as a secret name' }
    @{ Name = ' '; Kind = 'variable'; Message = 'and a blank one as a variable name' }
    @{ Name = '9LIVES'; Kind = 'variable'; Message = 'and one starting with a digit' }
    @{ Name = 'GITHUB_SHA'; Kind = 'variable'; Message = 'and one starting with GITHUB_' }
    @{ Name = 'github_sha'; Kind = 'secret'; Message = 'in any case' }
    @{ Name = '--user'; Kind = 'secret'; Message = 'and one that gh would read as an option' }
    @{ Name = 'A-B'; Kind = 'secret'; Message = 'and one with a dash' }
)

# Act / Assert
foreach ($case in $refused) {
    $like = [WildcardPattern]::Escape("'$($case.Name)' is not a $($case.Kind) name: $rule")
    Assert-Throws -ScriptBlock { & $module $assert $case.Name $case.Kind } -MessageLike $like -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a URL that carries a credential, given where a name belongs
$url = 'https://user:SENTINEL@github.com/o/r'
$like = [WildcardPattern]::Escape("'https://***@github.com/o/r' is not a secret name: $rule")

# Act / Assert
Assert-Throws -ScriptBlock { & $module $assert $url 'secret' } -MessageLike $like `
    -Message 'A URL is refused and shown without the credential it carried'

exit (Complete-TestRun)
