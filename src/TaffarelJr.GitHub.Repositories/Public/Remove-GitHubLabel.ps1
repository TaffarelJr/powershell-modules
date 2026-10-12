function Remove-GitHubLabel {
    <#
    .SYNOPSIS
        Deletes a label from a repository.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. A label
        piped in from Get-GitHubLabel, or given by its URL, is deleted from
        the repository its Url names; a -Repository naming another throws.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The label's name, its web URL
        (https://HOST/OWNER/REPO/labels/NAME), or a label object such as
        one Get-GitHubLabel returned.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the label's own repository, or
        for a bare name the current directory's; a label object with no
        Url, such as an issue's label, needs it. Given beside a label from
        another OWNER/REPO (or host), it throws.
        A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A label's name or web URL, or a label object such as one
        Get-GitHubLabel returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubLabel -Name 'stale' -Repository 'OWNER/REPO'

        Deletes the stale label from OWNER/REPO.
    .EXAMPLE
        Get-GitHubLabel -Repository 'OWNER/REPO' -Search 'stale' |
            Where-Object Name -EQ 'stale' |
            Remove-GitHubLabel

        Deletes OWNER/REPO's stale label, there and not in the current
        directory's repository: -Search narrows the listing past gh's
        first 30 labels, and the filter keeps the exact name only.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubLabel
    .LINK
        New-GitHubLabel
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Name,

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

            $given = $PSBoundParameters.ContainsKey('Repository')
            $named = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $label = ConvertTo-GitHubLabelReference -Label $Name -Repository $named
            $reference = $label.Repository
            $arguments = @('label', 'delete', '--yes', '--', $label.Name)
            $shownName = Hide-UrlCredential -Text $label.Name
            $activity = "Deleting label $shownName"
            $target = Format-GitHubTarget -Repository $reference -Item "label $shownName"
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete label')) {
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
}
