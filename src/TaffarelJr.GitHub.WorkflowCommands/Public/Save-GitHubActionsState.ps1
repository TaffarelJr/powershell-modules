function Save-GitHubActionsState {
    <#
    .SYNOPSIS
        Saves a value for this action's own post step to read back with
        Get-GitHubActionsState.
    .PARAMETER Name
        The state's name.
    .PARAMETER Value
        The value. May contain newlines.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidatePattern('\S')]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Value
    )

    process {
        if (-not $env:GITHUB_STATE) {
            throw 'GITHUB_STATE is not set - this must run inside a GitHub Actions step.'
        }

        Add-GitHubActionsCommandFile -Path $env:GITHUB_STATE -Name $Name -Value $Value
    }
}
