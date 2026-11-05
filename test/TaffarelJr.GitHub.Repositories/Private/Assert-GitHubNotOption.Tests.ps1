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
    param([string]$Value)

    Assert-GitHubNotOption -Value $Value
}
$rule = "starts with '-', which gh would read as an option."

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that do not start with a dash
$accepted = @('name', 'o/name', 'a-b', '', ' -x', "$([char]0x2212)x")

# Act / Assert
foreach ($value in $accepted) {
    Assert-Equal -Expected $true -Actual (& $module $assert $value) -Message "'$value' passes"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that start with one
$refused = @(
    @{ Value = '-x'; Message = 'A dash is refused' }
    @{ Value = '--yes'; Message = 'and so is a flag' }
    @{ Value = '-'; Message = 'and a lone dash' }
)

# Act / Assert
foreach ($case in $refused) {
    $like = [WildcardPattern]::Escape("'$($case.Value)' $rule")
    Assert-Throws -ScriptBlock { & $module $assert $case.Value } -MessageLike $like -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a URL that carries a credential, behind a dash
$like = [WildcardPattern]::Escape("'-https://***@github.com/o/r' $rule")

# Act / Assert
Assert-Throws -ScriptBlock { & $module $assert '-https://user:SENTINEL@github.com/o/r' } -MessageLike $like `
    -Message 'The value is shown without the credential it carried'

exit (Complete-TestRun)
