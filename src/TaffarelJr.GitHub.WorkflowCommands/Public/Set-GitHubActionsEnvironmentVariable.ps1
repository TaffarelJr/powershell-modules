function Set-GitHubActionsEnvironmentVariable {
    <#
    .SYNOPSIS
        Sets an environment variable for the rest of this step and every
        step after it.
    .DESCRIPTION
        Also sets it in this process immediately, since the file this
        writes to only takes effect for steps that start after the
        current one ends.
    .PARAMETER Name
        The variable's name.
    .PARAMETER Value
        The variable's value. May contain newlines.
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
        if (-not $env:GITHUB_ENV) {
            throw 'GITHUB_ENV is not set - this must run inside a GitHub Actions step.'
        }

        Add-GitHubActionsCommandFile -Path $env:GITHUB_ENV -Name $Name -Value $Value
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
}
