function Remove-GitHubRepository {
    <#
    .SYNOPSIS
        Deletes a repository from GitHub.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. The
        repository must be named: gh refuses to delete the current
        directory's repository without a confirmation prompt, and nothing
        here can answer one. Deleting needs the delete_repo scope on the
        token.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Repository
        The repository to delete, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object such as one Get-GitHubRepository returned -
        read by its Url first, so a GitHub Enterprise repository is
        deleted on its own host.
        A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The repository to delete - OWNER/REPO text, a URL, or a repository
        object such as one Get-GitHubRepository returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubRepository -Repository 'OWNER/REPO'

        Deletes OWNER/REPO.
    .EXAMPLE
        Get-GitHubRepository -List -Owner 'OWNER' -Topic 'retired' |
            Remove-GitHubRepository -WhatIf

        Shows which of OWNER's repositories carrying the retired topic
        would be deleted, without deleting any.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        New-GitHubRepository
    .LINK
        Get-GitHubRepository
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Repository
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

            $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            $target = Format-GitHubRepositoryName -Repository $reference
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete repository')) {
                return
            }

            $arguments = @('repo', 'delete', $reference, '--yes')
            Invoke-GitHubCommand -Activity "Deleting repository $reference" -Arguments $arguments | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
