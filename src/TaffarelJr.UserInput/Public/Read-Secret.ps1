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

        With input redirected from a pipe or a file, one line is read
        straight from it, and input already at its end gives an empty
        string, as the other prompts give theirs. Read-Host -AsSecureString
        cannot read redirected input and would wait on the console for good.
        A session started with -NonInteractive still fails with Read-Host's
        own error, which is a terminating error for the call.
    .PARAMETER Prompt
        The question shown to the user.
    .PARAMETER Hint
        Lines printed immediately before the prompt, for context.
    .INPUTS
        None. The question is given with -Prompt.
    .OUTPUTS
        System.String. The answer as typed, or an empty string when there is
        none.
    .EXAMPLE
        $token = Read-Secret -Prompt 'Token'
        if ($token) { $token | Set-EnvironmentVariable -Name 'MY_TOKEN' }

        An empty answer is not saved: an empty value would remove the variable.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Read-Input
    .LINK
        Set-EnvironmentVariable
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [string[]]$Hint
    )

    try {
        $ErrorActionPreference = 'Stop'

        Write-InputHint -Hint $Hint

        $fact = Get-HostFact
        if ($fact.InputRedirected -and -not (Test-NonInteractiveFlag -CommandLine $fact.CommandLine)) {
            return "$([Console]::In.ReadLine())"
        }

        $secure = Read-Host -AsSecureString $Prompt
        return [NetworkCredential]::new('', $secure).Password
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
