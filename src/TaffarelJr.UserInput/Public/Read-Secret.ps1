using namespace System.Net

function Read-Secret {
    <#
    .SYNOPSIS
        Prompts once for a value without echoing it.
    .DESCRIPTION
        Returned untrimmed and unvalidated -
        a token or password is opaque,
        so there is no rule worth applying to it.
        No default either:
        a secret has nothing sensible to fall back to on a bare Enter.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Hint
        Lines printed immediately before the prompt, for context.
    .EXAMPLE
        Read-Secret -Prompt 'Token' | Set-EnvironmentVariable -Name 'MY_TOKEN'
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [string[]]$Hint
    )

    Write-InputHint -Hint $Hint

    $secure = Read-Host -AsSecureString $Prompt
    return [NetworkCredential]::new('', $secure).Password
}
