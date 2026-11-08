function Rename-GitHubRepository {
    <#
    .SYNOPSIS
        Renames a repository on GitHub.
    .DESCRIPTION
        Renames without asking by default; -Confirm asks first. It passes
        gh's --yes, so the repository must be named: gh would otherwise
        rename whichever repository the current directory implies, which
        in a fork's clone can be the upstream repository.

        Only the name changes; moving a repository to another owner is a
        transfer, which GitHub only offers through its website.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Repository
        The repository to rename, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object such as one a listing returned.
        A -Repository given as $null throws.
    .PARAMETER NewName
        The new name, without an owner.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The repository is given as a parameter.
    .OUTPUTS
        None.
    .EXAMPLE
        Rename-GitHubRepository 'OWNER/OLD-NAME' 'NEW-NAME'

        Renames OWNER/OLD-NAME to OWNER/NEW-NAME.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubRepository
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Repository,

        [Parameter(Mandatory, Position = 1)]
        [ValidateScript({ Assert-GitHubNotOption -Value $_ })]
        [string]$NewName
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

        $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
        $arguments = @('repo', 'rename', $NewName, '--yes')
        $shownName = Hide-UrlCredential -Text $NewName
        $activity = "Renaming $reference to $shownName"
        $target = Format-GitHubRepositoryName -Repository $reference
        if (-not $PSCmdlet.ShouldProcess($target, "Rename repository to $shownName")) {
            return
        }

        Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $reference | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
