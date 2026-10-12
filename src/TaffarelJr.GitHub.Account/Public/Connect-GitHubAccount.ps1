function Connect-GitHubAccount {
    <#
    .SYNOPSIS
        Stores a token as a gh login for a host.
    .DESCRIPTION
        The token travels to gh on standard input, never as an argument,
        so it cannot appear in a failure message. gh's browser-based
        login flow is not offered here: gh falls back to it when the
        token it reads is blank, so an empty or blank token is refused
        before gh starts. For a headless job, setting GH_TOKEN in the
        environment is simpler still and needs no login at all.

        Called with no token, PowerShell prompts for -SecureToken, so what
        is typed is masked.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Token
        A personal access token. gh auth login's own help says: "The
        minimum required scopes for the token are: `repo`, `read:org`, and
        `gist`." gh refuses a classic token that lacks repo or read:org
        (write:org or admin:org also do for the second); a fine-grained
        or app token reports no scopes and is not checked. A token's
        scopes are fixed when it is made, so none are requested here. A
        token typed as a literal on the command line lands in
        PSReadLine's history and in any transcript: prefer -SecureToken.
        A blank token is refused.
    .PARAMETER SecureToken
        The same token as a SecureString, for a caller that does not want
        it in plain text any longer than it has to be. It is turned into
        plain text only inside the expressions that check it and hand it
        to gh, so no variable of this function holds it - but a script
        trace (Set-PSDebug -Trace 2) of the helper that starts gh still
        shows it. An empty or blank token is refused.
    .PARAMETER Hostname
        The host to log in to (gh's --hostname). Omit it for github.com.
        An empty value is refused; leave it out for the default.
    .PARAMETER GitProtocol
        The protocol gh configures git to use for this host: ssh or
        https.
    .PARAMETER InsecureStorage
        Stores the token in a plain text file instead of the system
        credential store.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        $token = Read-Host 'Token' -AsSecureString
        Connect-GitHubAccount -SecureToken $token -Hostname 'ghe.example.com'

        Asks for the token without echoing it and stores it as the login
        for ghe.example.com.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Disconnect-GitHubAccount
    .LINK
        Get-GitHubAuthStatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'SecureToken', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Token')]
        [string]$Token,

        [Parameter(Mandatory, ParameterSetName = 'SecureToken')]
        [securestring]$SecureToken,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname,

        [ValidateSet('ssh', 'https')]
        [string]$GitProtocol,

        [switch]$InsecureStorage
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        # Checked without a variable, for the same reason as the conversion below.
        if ($PSCmdlet.ParameterSetName -eq 'SecureToken') {
            if ($SecureToken.Length -eq 0 -or
                [string]::IsNullOrWhiteSpace((ConvertFrom-SecureString -SecureString $SecureToken -AsPlainText))) {
                throw '-SecureToken is blank, and gh would fall back to its browser login: give the token.'
            }
        }
        elseif ([string]::IsNullOrWhiteSpace($Token)) {
            throw '-Token is blank, and gh would fall back to its browser login: give the token.'
        }

        $arguments = @('auth', 'login', '--with-token')
        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        if ($GitProtocol) {
            $arguments += @('--git-protocol', $GitProtocol.ToLowerInvariant())
        }

        if ($InsecureStorage) {
            $arguments += '--insecure-storage'
        }

        $target = if ($Hostname) { $Hostname } else { 'github.com' }
        if (-not $PSCmdlet.ShouldProcess($target, 'Store gh login')) {
            return
        }

        # Converted in the call itself, so no variable of THIS function holds the plain token;
        # the helper below still does.
        if ($PSCmdlet.ParameterSetName -eq 'SecureToken') {
            Invoke-GitHubCommand -Activity 'Logging in' -Argument $arguments `
                -StdIn (ConvertFrom-SecureString -SecureString $SecureToken -AsPlainText) | Out-Null
            return
        }

        Invoke-GitHubCommand -Activity 'Logging in' -Argument $arguments -StdIn $Token | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
