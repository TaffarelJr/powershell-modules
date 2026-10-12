function New-GitHubLabel {
    <#
    .SYNOPSIS
        Creates a label, or with -Force updates one that already exists.
    .DESCRIPTION
        Adds a label to one repository. A label that already exists makes
        gh fail, unless -Force is given with -Color, which then sets the
        label's color and description instead. Returns nothing.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The label's name. A blank one is refused.
    .PARAMETER Color
        The label's color, as six hex digits. gh picks one at random
        when omitted. A blank one is refused.
    .PARAMETER Description
        The label's description. A blank one is refused.
    .PARAMETER Force
        Updates the color and description of a label that already
        exists, instead of failing. Needs -Color: gh would otherwise give
        the existing label a random color.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository.
        A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The label is given as parameters.
    .OUTPUTS
        None.
    .EXAMPLE
        New-GitHubLabel -Name 'needs-triage' -Color 'fbca04' `
            -Repository 'OWNER/REPO'

        Creates a yellow needs-triage label in OWNER/REPO.
    .EXAMPLE
        New-GitHubLabel -Name 'bug' -Color 'd73a4a' -Force

        Creates the bug label in the current directory's repository, or
        recolors it if it already exists.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubLabel
    .LINK
        Copy-GitHubLabel
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Name is blank: give the label's name.")]
        [string]$Name,

        [string]$Color,

        [string]$Description,

        [switch]$Force,

        [object]$Repository
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

        $blank = [ordered]@{
            Color       = 'six hex digits'
            Description = 'the description'
        }
        foreach ($option in $blank.PSBase.Keys) {
            $present = $PSBoundParameters.ContainsKey($option)
            if ($present -and [string]::IsNullOrWhiteSpace($PSBoundParameters[$option])) {
                throw "-$option is blank: give $($blank[$option]), or leave it out."
            }
        }

        $shownName = Hide-UrlCredential -Text $Name
        if ($Force -and -not $Color) {
            throw "-Force works only with -Color: without one gh would recolor an existing '$shownName' at random." +
            ' Give -Color too, or leave -Force off.'
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $arguments = @('label', 'create')
        if ($Color) {
            $arguments += "--color=$Color"
        }

        if ($Description) {
            $arguments += "--description=$Description"
        }

        if ($Force) {
            $arguments += '--force'
        }

        $arguments += @('--', $Name)
        $target = Format-GitHubTarget -Repository $reference -Item "label $shownName"
        $action = 'Create label'
        if ($Force) {
            $action = 'Create or update label'
        }

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        Invoke-GitHubCommand -Activity "Creating label $shownName" `
            -Arguments $arguments `
            -Repository $reference | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
