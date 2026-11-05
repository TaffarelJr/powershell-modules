function Get-GitHubAuthStatus {
    <#
    .SYNOPSIS
        Returns every account gh knows about, with its host and whether
        it is the active one there.
    .DESCRIPTION
        gh reports its accounts grouped under each host; this flattens
        them into one object per account, each carrying its Host, so a
        caller can filter on either without walking a nested map.

        An account whose token gh could not use is listed too, with State
        'error' and an Error saying why - a GH_TOKEN in the environment
        that GitHub rejects shows up this way, with an empty Login. Check
        State, not just that something came back. Nothing is returned, and
        nothing thrown, when gh has no login at all. Needs gh 2.81 or later.

        gh leaves a field out of an account when it is empty; here every
        object has every property, so a strict-mode caller can read Error,
        Scopes, or Token on any of them.
    .PARAMETER Hostname
        Reports only this host's accounts (gh's --hostname). An empty value
        is refused; leave it out for the default, every host.
    .PARAMETER Active
        Reports only the active account on each host.
    .PARAMETER ShowToken
        Includes each account's token in plain text. The objects then hold
        secrets: an unassigned call prints every token to the console, so
        keep them out of logs and transcripts.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per account - Host, Login, Active, State, Error,
        TokenSource, GitProtocol, Scopes, and Token. Error is $null unless
        State is 'error'; Scopes is an array, empty when gh reports none (a
        fine-grained or app token, or one it could not check); Token is
        $null without -ShowToken. Any further field gh reports follows
        these, under its PascalCase name.
    .EXAMPLE
        Get-GitHubAuthStatus |
            Where-Object State -NE 'success' |
            Select-Object Host, Login, Error

        Lists every login gh cannot use, with the reason.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Connect-GitHubAccount
    .LINK
        Switch-GitHubAccount
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname,

        [switch]$Active,

        [switch]$ShowToken
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []')
        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        if ($Active) {
            $arguments += '--active'
        }

        if ($ShowToken) {
            $arguments += '--show-token'
        }

        $out = Invoke-GitHubCommand -Activity 'Reading authentication status' -Argument $arguments
        $entries = ConvertFrom-GitHubJson -Line $out
        $names = 'Host', 'Login', 'Active', 'State', 'Error', 'TokenSource', 'GitProtocol', 'Scopes', 'Token'
        foreach ($entry in $entries) {
            $account = [ordered]@{}
            foreach ($name in $names) {
                $field = $entry.PSObject.Properties[$name]
                $account[$name] = if ($field) { $field.Value } else { $null }
            }

            foreach ($field in $entry.PSObject.Properties) {
                if (-not $account.Contains($field.Name)) {
                    $account[$field.Name] = $field.Value
                }
            }

            # gh reports scopes as the comma-separated text of GitHub's X-OAuth-Scopes header.
            $scopes = "$($account.Scopes)".Split(',').Trim()
            $account.Scopes = [string[]]@($scopes.Where({ $_ }))
            [PSCustomObject]$account
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
