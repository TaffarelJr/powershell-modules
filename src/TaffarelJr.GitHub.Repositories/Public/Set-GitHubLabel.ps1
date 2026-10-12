function Set-GitHubLabel {
    <#
    .SYNOPSIS
        Changes a label's name, color, or description.
    .DESCRIPTION
        Says what to change, or throws: gh would refuse a call that
        changes nothing. A label piped in from Get-GitHubLabel, or given
        by its URL, is changed in the repository its Url names; a
        -Repository naming another throws.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The label's current name, its web URL
        (https://HOST/OWNER/REPO/labels/NAME), or a label object such as
        one Get-GitHubLabel returned.
    .PARAMETER NewName
        The label's new name.
    .PARAMETER Color
        The label's new color, as six hex digits.
    .PARAMETER Description
        The label's new description. An empty one is refused: gh drops an
        empty --description, so it cannot clear a description.
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
        Set-GitHubLabel -Name 'bug' -Color 'd73a4a' -Repository 'OWNER/REPO'

        Recolors the bug label of OWNER/REPO.
    .EXAMPLE
        Get-GitHubLabel -Repository 'OWNER/REPO' -Search 'bug' |
            Where-Object Name -EQ 'bug' |
            Set-GitHubLabel -NewName 'defect'

        Renames OWNER/REPO's bug label to defect, there and not in the
        current directory's repository.
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

        [string]$NewName,

        [string]$Color,

        [string]$Description,

        [object]$Repository
    )

    begin {
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

            if ($PSBoundParameters.ContainsKey('Description') -and $Description.Length -eq 0) {
                throw '-Description is empty, and gh cannot clear a label''s description - it drops an empty one:' +
                ' give the new text, or leave -Description out.'
            }

            $changes = @()
            if ($NewName) {
                $changes += "--name=$NewName"
            }

            if ($Color) {
                $changes += "--color=$Color"
            }

            if ($Description) {
                $changes += "--description=$Description"
            }

            if ($changes.Count -eq 0) {
                throw 'Say what to change - -NewName, -Color, or -Description.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $given = $PSBoundParameters.ContainsKey('Repository')
            $named = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $label = ConvertTo-GitHubLabelReference -Label $Name -Repository $named
            $reference = $label.Repository
            $arguments = @('label', 'edit') + $changes + @('--', $label.Name)
            $shownName = Hide-UrlCredential -Text $label.Name
            $activity = "Editing label $shownName"
            $target = Format-GitHubTarget -Repository $reference -Item "label $shownName"
            if (-not $PSCmdlet.ShouldProcess($target, 'Edit label')) {
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
