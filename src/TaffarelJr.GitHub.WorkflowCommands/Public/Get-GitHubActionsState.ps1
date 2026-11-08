function Get-GitHubActionsState {
    <#
    .SYNOPSIS
        Reads a value this action saved in an earlier step with
        Save-GitHubActionsState.
    .DESCRIPTION
        A value saved in an action's pre step is readable in its main and
        post steps; one saved in its main step, in its post step. The
        runner exposes each as STATE_<name> in the environment - there is
        no file to read on this side, unlike the save side.
    .PARAMETER Name
        The state's name.
    .INPUTS
        System.Object. An object with a Name property.
    .OUTPUTS
        System.String. The saved value, or an empty string if nothing was
        saved under that name.
    .EXAMPLE
        $containerId = Get-GitHubActionsState -Name 'containerId'

        Reads the value an earlier step saved under that name.
    .EXAMPLE
        [PSCustomObject]@{ Name = 'containerId' } | Get-GitHubActionsState

        Reads the state named by each piped object's Name property.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Save-GitHubActionsState
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidatePattern('\S', ErrorMessage = '-Name is blank: give a name.')]
        [string]$Name
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            return [string]([Environment]::GetEnvironmentVariable("STATE_$Name"))
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
