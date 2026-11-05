function Set-GitHubActionsOutput {
    <#
    .SYNOPSIS
        Sets a step output, readable by later steps as
        steps.<id>.outputs.<name>.
    .DESCRIPTION
        Appends the output to the file GITHUB_OUTPUT names, which the runner
        reads for the steps that start after this one ends: the output is
        for later steps, and not for the step that sets it. A step must
        have an id for later steps to name it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The output's name. It must not contain a line break, '=' or '<<',
        or a control character other than a tab, or end in '<'.
    .PARAMETER Value
        The output's value. May contain newlines, but not a NUL character.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. An object with Name and Value properties.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Set-GitHubActionsOutput -Name 'version' -Value '1.2.3'

        Sets the output, which later steps read as steps.<id>.outputs.version.
    .EXAMPLE
        [PSCustomObject]@{ Name = 'version'; Value = '1.2.3' } |
            Set-GitHubActionsOutput

        Sets the output each piped object names, to its Value property.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidatePattern('\S', ErrorMessage = '-Name is blank: give a name.')]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Value
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

            $text = ConvertTo-GitHubActionsCommandFileText -Name $Name -Value $Value
            $file = Resolve-GitHubActionsFilePath -Variable 'GITHUB_OUTPUT'
            $shownName = Hide-UrlCredential -Text $Name
            if (-not $PSCmdlet.ShouldProcess($shownName, 'Set step output')) {
                return
            }

            Add-GitHubActionsFileText -Variable 'GITHUB_OUTPUT' -Path $file -Text $text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
