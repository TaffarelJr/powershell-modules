function Set-GitHubConfig {
    <#
    .SYNOPSIS
        Updates one of gh's own configuration values.
    .DESCRIPTION
        This is gh's own local CLI configuration, not a GitHub resource -
        see Get-GitHubConfig for why.

        A name gh does not list throws. gh itself accepts one, with only a
        warning on stderr, and writes it into the config file - so a
        misspelled name would be stored and never noticed.

        A value with a line break throws: gh lists its settings one
        key=value line each, so the rest of the value would read back as
        another setting.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The setting to change, such as 'editor'.
    .PARAMETER Value
        The new value, on one line. It may start with a dash, or be empty. It
        travels as an argument, so -Verbose output and every failure message
        show *** in its place, unless it is fewer than four characters. Give
        a secret by variable: PowerShell's own error view quotes the line of
        the calling script, so a secret written in it is shown there.
    .PARAMETER Hostname
        Sets the per-host override for this host (gh's --host) instead of
        the global setting. An empty value is refused; leave it out for
        the default, the global setting.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        Set-GitHubConfig -Name 'git_protocol' -Value 'ssh'

        Makes gh configure git to use ssh, for every host that sets no value
        of its own.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Get-GitHubConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Value,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
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

        $shownName = Hide-UrlCredential -Text $Name
        if ($Value -match '[\r\n]') {
            throw "-Value for '$shownName' holds a line break, but a gh setting is one line:" +
            ' give the value on one line.'
        }

        try {
            $settings = @(Get-GitHubConfig)
        }
        catch {
            throw "Setting config $shownName failed: could not read gh's settings to check the name." +
            " $($_.Exception.Message)"
        }

        # Not ForEach-Object Name: under -WhatIf it reads no property, so every name would look unknown.
        $known = @(foreach ($setting in $settings) { $setting.Name })

        if ($known -cnotcontains $Name) {
            throw "-Name '$shownName' is not a setting gh has: give one of $($known -join ', ')."
        }

        $arguments = @('config', 'set')
        if ($Hostname) {
            $arguments += @('--host', $Hostname)
        }

        # After the --, a value that starts with a dash is still a value.
        $arguments += @('--', $Name, $Value)
        $target = if ($Hostname) { "$Name on $Hostname" } else { $Name }
        if (-not $PSCmdlet.ShouldProcess($target, 'Set gh setting')) {
            return
        }

        Invoke-GitHubCommand -Activity "Setting config $Name" -Argument $arguments -Mask $Value | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
