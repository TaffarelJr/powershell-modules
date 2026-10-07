function Remove-GitRemote {
    <#
    .SYNOPSIS
        Removes a remote, doing nothing for one that does not exist.
    .DESCRIPTION
        Only a missing remote is tolerated: any other failure, such as a
        path that is not a repository, still throws.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The remote to remove. Accepted from the pipeline. A credential its
        name carries is hidden in -WhatIf and in every message.
    .PARAMETER RepoPath
        The repo to remove it from. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        The name of a remote.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Remove-GitRemote -Name 'upstream'

        Removes a remote, doing nothing when there is no such remote.
    .EXAMPLE
        'old', 'backup' | Remove-GitRemote -RepoPath 'C:\src\project'

        Removes two remotes from another repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitRemote
    .LINK
        Set-GitRemote
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
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

            $remotes = @(Invoke-GitCommand -Activity 'Listing remotes' -Arguments @('remote') -RepoPath $RepoPath)
            if ($remotes -cnotcontains $Name) {
                return
            }

            $shownName = Hide-UrlCredential -Text $Name
            $activity = "Removing the $shownName remote"
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
            if ($PSCmdlet.ShouldProcess("$root remote $shownName", 'Remove remote')) {
                Invoke-GitCommand -Activity $activity `
                    -Arguments @('remote', 'remove', $Name) -RepoPath $RepoPath | Out-Null
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
