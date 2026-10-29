function Remove-GitHubGist {
    <#
    .SYNOPSIS
        Deletes a gist.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. Needs gh
        2.66 or later, the first with a --yes to confirm in advance.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Id
        The gist to delete: its id, a URL of it, or a gist object, read by
        its Id, HtmlUrl, or Url.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The gist to delete, bound to -Id: its id, a URL of it, or a gist
        object, such as one Get-GitHubGist returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubGist -Id 0123456789abcdef0123456789abcdef

        Deletes the gist. With -WhatIf it only says what it would delete.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/README.md
    .LINK
        Get-GitHubGist
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Id
    )

    process {
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

            $gistId = ConvertTo-GitHubGistId -Id $Id
            if (-not $PSCmdlet.ShouldProcess("gist $gistId", 'Delete gist')) {
                return
            }

            $arguments = @('gist', 'delete', $gistId, '--yes')
            Invoke-GitHubCommand -Activity "Deleting gist $gistId" -Arguments $arguments | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
