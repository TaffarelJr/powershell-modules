function Clear-GitHubConfigCache {
    <#
    .SYNOPSIS
        Clears gh's own local HTTP response cache.
    .DESCRIPTION
        This is the cache gh keeps of API responses (filled by gh api
        --cache and similar), not gh's configuration and not anything
        stored on GitHub: every setting stays as it was. The name follows
        gh's own command, gh config clear-cache.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        Clear-GitHubConfigCache

        Clears the local cache of API responses that gh keeps; gh's settings
        and logins stay as they are.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

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

        if (-not $PSCmdlet.ShouldProcess("gh's local HTTP response cache", 'Clear cache')) {
            return
        }

        Invoke-GitHubCommand -Activity "Clearing gh's cache" -Argument @('config', 'clear-cache') | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
