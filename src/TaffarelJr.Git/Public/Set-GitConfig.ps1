function Set-GitConfig {
    <#
    .SYNOPSIS
        Writes a config value.
    .DESCRIPTION
        Without -Global, the value is written to the repo's own config, where
        it takes precedence over the global config in that repo.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The config key, such as 'user.name'. A credential it carries, as in
        the 'url.https://x-access-token:TOKEN@github.com/.insteadOf' a CI job
        sets, is hidden in -WhatIf, -Verbose and every message.
    .PARAMETER Value
        The value to set it to. It is hidden in -Verbose and in every
        message, which show *** in its place, so a secret is safe to give,
        unless it is fewer than four characters. Give it by variable:
        PowerShell's own error view quotes the line of the calling script.
    .PARAMETER Global
        Writes to the global config instead of the repo's own.
    .PARAMETER RepoPath
        The repo to write to. Omit it to use the current working
        directory. Not used with -Global, which writes the same file from
        anywhere, whatever repository an inherited GIT_DIR or GIT_CONFIG
        names.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Set-GitConfig -Name 'user.email' -Value 'me@example.com'

        Sets the email address for the current repository only.
    .EXAMPLE
        Set-GitConfig -Name 'init.defaultBranch' -Value 'main' -Global

        Sets a value in the global config.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]$Value,

        [switch]$Global,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
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
        $activity = "Setting $shownName"
        $arguments = @('config')
        $in = $RepoPath
        $where = 'global'
        if ($Global) {
            $arguments += '--global'
            $in = $null
        }
        else {
            $where = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
        }

        $arguments += @($Name, $Value)
        if (-not $PSCmdlet.ShouldProcess("$where config $shownName", 'Set config value')) {
            return
        }

        Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $in `
            -NoRepository:$Global -Mask $Value | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
