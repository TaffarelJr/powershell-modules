function Set-GitHubVariable {
    <#
    .SYNOPSIS
        Creates or updates an Actions variable at a repository,
        environment, or organization level.
    .DESCRIPTION
        The value travels to gh on standard input rather than as an
        argument, so a multi-line value or one starting with a dash
        arrives intact.
    .PARAMETER Name
        The variable's name.
    .PARAMETER Value
        The variable's value.
    .PARAMETER EnvFile
        A dotenv-formatted file whose every entry is set as a variable,
        instead of one -Name/-Value pair.
    .PARAMETER Environment
        Sets a deployment environment's variable instead of the
        repository's own.
    .PARAMETER Organization
        Sets an organization's variable instead of a repository's.
    .PARAMETER Visibility
        Which repositories can use an organization variable: all,
        private, or selected.
    .PARAMETER Repos
        The repositories that can use an organization variable.
    .PARAMETER Repository
        The repository to set it on, in [HOST/]OWNER/REPO form. Omit it
        to use the current directory's repository.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Value')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'Value')]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory, ParameterSetName = 'EnvFile')]
        [string]$EnvFile,

        [string]$Environment,

        [string]$Organization,

        [ValidateSet('all', 'private', 'selected')]
        [string]$Visibility,

        [string[]]$Repos,

        [string]$Repository
    )

    $arguments = @('variable', 'set')
    if ($PSCmdlet.ParameterSetName -eq 'Value') {
        $arguments += $Name
    }
    else {
        $arguments += @('--env-file', $EnvFile)
    }

    if ($Environment) {
        $arguments += @('--env', $Environment)
    }

    if ($Organization) {
        $arguments += @('--org', $Organization)
    }

    if ($Visibility) {
        $arguments += @('--visibility', $Visibility)
    }

    if ($Repos) {
        $arguments += @('--repos', ($Repos -join ','))
    }

    $extra = @{}
    if ($PSCmdlet.ParameterSetName -eq 'Value') {
        $extra['StdIn'] = $Value
    }

    $activity = if ($PSCmdlet.ParameterSetName -eq 'Value') { "Setting variable $Name" } else { "Setting variables from $EnvFile" }
    Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $Repository @extra | Out-Null
}
