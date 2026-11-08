function Save-GitHubActionsState {
    <#
    .SYNOPSIS
        Saves a value for this action's later steps to read back with
        Get-GitHubActionsState.
    .DESCRIPTION
        A value saved in an action's pre step is readable in its main and
        post steps; one saved in its main step, in its post step.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The state's name. It must not contain a line break, '=' or '<<',
        or a control character other than a tab, or end in '<'.
    .PARAMETER Value
        The value. May contain newlines, but not a NUL character.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. An object with Name and Value properties.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Save-GitHubActionsState -Name 'containerId' -Value 'a1b2c3'

        Saves the value for a later step of this action to read back.
    .EXAMPLE
        [PSCustomObject]@{ Name = 'containerId'; Value = 'a1b2c3' } |
            Save-GitHubActionsState

        Saves the state each piped object names, with its Value property.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Get-GitHubActionsState
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
            $file = Resolve-GitHubActionsFilePath -Variable 'GITHUB_STATE'
            $shownName = Hide-UrlCredential -Text $Name
            if (-not $PSCmdlet.ShouldProcess($shownName, 'Save action state')) {
                return
            }

            Add-GitHubActionsFileText -Variable 'GITHUB_STATE' -Path $file -Text $text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
