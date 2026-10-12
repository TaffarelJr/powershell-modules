function Set-GitHubDefaultRepository {
    <#
    .SYNOPSIS
        Sets, or unsets, the repository gh treats as the default for the
        current directory's clone.
    .DESCRIPTION
        A clone with several GitHub remotes - a fork and its upstream -
        leaves gh unsure which one a pull request or run command means;
        the default settles that. gh 2.66 and later do not consult it for
        secrets.

        -WhatIf and -Confirm name the clone by its full path: PowerShell's
        current file system location, where gh runs.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Repository
        The repository to make the default, in [HOST/]OWNER/REPO form or as
        a URL, or a repository object, or the name of a git remote that
        points at it. A remote name needs gh 2.85 or later.
        A -Repository given as $null throws.
    .PARAMETER Unset
        Clears the default instead. Needs gh 2.102 or later: an older gh
        refuses to unset it without a terminal to ask in.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The repository is given as a parameter.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-GitHubDefaultRepository -Repository 'OWNER/REPO'

        Makes OWNER/REPO the repository gh uses for this clone.
    .EXAMPLE
        Set-GitHubDefaultRepository -Unset

        Clears the default, so gh asks again when the clone has several
        GitHub remotes.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubDefaultRepository
    #>
    [CmdletBinding(DefaultParameterSetName = 'Set', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Set')]
        [object]$Repository,

        [Parameter(Mandatory, ParameterSetName = 'Unset')]
        [switch]$Unset
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

        $arguments = @('repo', 'set-default', '--unset')
        $action = 'Unset the default repository'
        if (-not $Unset) {
            $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            $arguments = @('repo', 'set-default', $reference)
            $action = "Set the default repository to $(Format-GitHubRepositoryName -Repository $reference)"
        }

        $clone = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
        if (-not $PSCmdlet.ShouldProcess($clone, $action)) {
            return
        }

        Invoke-GitHubCommand -Activity 'Setting the default repository' -Arguments $arguments | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
