function Set-GitHubActionsEnvironmentVariable {
    <#
    .SYNOPSIS
        Sets an environment variable for the rest of this step and every
        step after it.
    .DESCRIPTION
        Also sets it in this process immediately, since the file this
        writes to only takes effect for steps that start after the
        current one ends. An empty value reaches later steps as an empty
        value, but removes the variable from this process, as setting a
        process variable to nothing does.

        NODE_OPTIONS throws in any casing, as the runner refuses it from
        this file. So does a name the runner sets for every step itself,
        over this file: GITHUB_ACTIONS, the GITHUB_ names it gives from the
        github context (GITHUB_SHA, GITHUB_OUTPUT, and the like), and the
        RUNNER_ names it gives from the runner context (RUNNER_OS,
        RUNNER_TEMP, and the like) - in any casing on Windows, in the
        runner's own casing elsewhere, as environment names are compared
        there. Later steps would see the runner's value, not the one this
        process had already taken. Any other name, GITHUB_TOKEN or CI
        among them, reaches later steps as written.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The variable's name. It must not contain a line break, '=' or
        '<<', or a control character other than a tab, or end in '<'.
    .PARAMETER Value
        The variable's value. May contain newlines, but not a NUL
        character.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. An object with Name and Value properties.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Set-GitHubActionsEnvironmentVariable -Name 'BUILD_MODE' -Value 'Release'

        Sets the variable for this process and for every later step.
    .EXAMPLE
        [PSCustomObject]@{ Name = 'BUILD_MODE'; Value = 'Release' } |
            Set-GitHubActionsEnvironmentVariable

        Sets the variable each piped object names, to its Value property.
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

            if ($Name -eq 'NODE_OPTIONS') {
                throw ('NODE_OPTIONS cannot be set for later steps: the runner refuses it from GITHUB_ENV. ' +
                    "Set it in the workflow's own env instead.")
            }

            if (Test-GitHubActionsRunnerVariable -Name $Name -IgnoreCase:$IsWindows) {
                throw ("'$Name' is set by the runner for every step, " +
                    "so later steps would see the runner's value, not this one. Give another name.")
            }

            $text = ConvertTo-GitHubActionsCommandFileText -Name $Name -Value $Value
            $file = Resolve-GitHubActionsFilePath -Variable 'GITHUB_ENV'
            $shownName = Hide-UrlCredential -Text $Name
            $action = 'Set environment variable for later steps and this process'
            if (-not $PSCmdlet.ShouldProcess($shownName, $action)) {
                return
            }

            Add-GitHubActionsFileText -Variable 'GITHUB_ENV' -Path $file -Text $text
            [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
