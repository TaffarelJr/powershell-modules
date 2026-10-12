function Copy-GitHubLabel {
    <#
    .SYNOPSIS
        Copies every label from one repository into another.
    .DESCRIPTION
        Labels the destination already has are skipped unless -Force
        overwrites them; labels only the destination has are left alone.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Source
        The repository to copy labels from, in [HOST/]OWNER/REPO form or as
        a URL, or a repository object.
    .PARAMETER Force
        Overwrites a destination label that already exists.
    .PARAMETER Repository
        The repository to copy labels into, in [HOST/]OWNER/REPO form or as
        a URL, or a repository object. Omit it to use the current
        directory's repository.
        A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The source repository is given as a parameter.
    .OUTPUTS
        None.
    .EXAMPLE
        Copy-GitHubLabel -Source 'OWNER/TEMPLATE' -Repository 'OWNER/REPO'

        Copies the labels of OWNER/TEMPLATE into OWNER/REPO, skipping any
        that OWNER/REPO already has.
    .EXAMPLE
        Copy-GitHubLabel 'OWNER/TEMPLATE' -Force

        Copies them into the current directory's repository, overwriting
        labels of the same name.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubLabel
    .LINK
        New-GitHubLabel
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Source,

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

        $from = ConvertTo-GitHubRepositoryReference -Repository $Source -Name 'Source'
        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $arguments = @('label', 'clone', $from)
        if ($Force) {
            $arguments += '--force'
        }

        $target = Format-GitHubTarget -Repository $reference
        $action = "Copy labels from $(Format-GitHubRepositoryName -Repository $from)"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        Invoke-GitHubCommand -Activity "Copying labels from $from" `
            -Arguments $arguments `
            -Repository $reference | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
