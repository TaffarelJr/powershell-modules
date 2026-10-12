function Set-GitHubActionsOutput {
    <#
    .SYNOPSIS
        Sets a step output, readable by later steps as
        steps.<id>.outputs.<name>.
    .PARAMETER Name
        The output's name.
    .PARAMETER Value
        The output's value. May contain newlines.
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
        if (-not $env:GITHUB_OUTPUT) {
            throw 'GITHUB_OUTPUT is not set - this must run inside a GitHub Actions step.'
        }

        Add-GitHubActionsCommandFile -Path $env:GITHUB_OUTPUT -Name $Name -Value $Value
    }
}
