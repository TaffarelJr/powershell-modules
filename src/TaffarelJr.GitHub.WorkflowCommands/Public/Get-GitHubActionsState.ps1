function Get-GitHubActionsState {
    <#
    .SYNOPSIS
        Reads a value this action's own main step saved with
        Save-GitHubActionsState.
    .DESCRIPTION
        The runner exposes every saved state to the post step as
        STATE_<name> in the environment - there is no file to read on
        this side, unlike the save side.
    .PARAMETER Name
        The state's name.
    .OUTPUTS
        The saved value, or an empty string if nothing was saved under
        that name.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidatePattern('\S')]
        [string]$Name
    )

    process {
        return [string]([Environment]::GetEnvironmentVariable("STATE_$Name"))
    }
}
