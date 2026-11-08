function Remove-GitTag {
    <#
    .SYNOPSIS
        Deletes a local tag.
    .DESCRIPTION
        Deletes the tag from this repository only; a remote's copy is left
        alone. A tag that does not exist throws. Nothing asks for
        confirmation unless -Confirm is given.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The tag to delete. Accepted from the pipeline, including by
        property name, so a filtered list from Get-GitTag can be piped
        straight in.
    .PARAMETER RepoPath
        The repo to delete it from. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        The name of a tag, or an object with a Name property.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Remove-GitTag -Name 'v1.2.0-rc1'

        Deletes a local tag.
    .EXAMPLE
        Get-GitTag -Pattern '*-rc*' | Remove-GitTag

        Deletes every local release-candidate tag.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitTag
    .LINK
        New-GitTag
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
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

            $activity = "Deleting tag $Name"
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
            $exists = Invoke-GitCommand -Activity $activity `
                -Arguments @('show-ref', '--verify', '--quiet', "refs/tags/$Name") -RepoPath $RepoPath -Tolerant
            if (-not $exists.Ok) {
                throw "$activity failed: there is no tag named '$Name'."
            }

            if (-not $PSCmdlet.ShouldProcess("$root tag $Name", 'Delete tag')) {
                return
            }

            Invoke-GitCommand -Activity $activity `
                -Arguments @('tag', '-d', $Name) -RepoPath $RepoPath | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
