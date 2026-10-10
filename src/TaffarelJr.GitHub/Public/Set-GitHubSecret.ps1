function Set-GitHubSecret {
    <#
    .SYNOPSIS
        Creates or updates a secret at a repository, environment,
        organization, or user level.
    .DESCRIPTION
        The value travels to gh on standard input, never as an argument,
        so it cannot appear in a failure message or a process listing.
        gh encrypts it locally before sending it to GitHub.
    .PARAMETER Name
        The secret's name.
    .PARAMETER Value
        The secret's value.
    .PARAMETER EnvFile
        A dotenv-formatted file whose every entry is set as a secret,
        instead of one -Name/-Value pair.
    .PARAMETER Environment
        Sets a deployment environment's secret instead of the
        repository's own.
    .PARAMETER Organization
        Sets an organization's secret instead of a repository's.
    .PARAMETER User
        Sets a Codespaces secret for the current user.
    .PARAMETER Application
        Sets the secret for one application only: actions, agents,
        codespaces, or dependabot.
    .PARAMETER Visibility
        Which repositories can use an organization secret: all, private,
        or selected.
    .PARAMETER Repos
        The repositories that can use an organization or user secret.
    .PARAMETER NoReposSelected
        Lets no repository use the organization secret.
    .PARAMETER Repository
        The repository to set it on, in [HOST/]OWNER/REPO form. Omit it
        to use the current directory's repository.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Value')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'Value')]
        [string]$Value,

        [Parameter(Mandatory, ParameterSetName = 'EnvFile')]
        [string]$EnvFile,

        [string]$Environment,

        [string]$Organization,

        [switch]$User,

        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [ValidateSet('all', 'private', 'selected')]
        [string]$Visibility,

        [string[]]$Repos,

        [switch]$NoReposSelected,

        [string]$Repository
    )

    $arguments = @('secret', 'set')
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

    if ($User) {
        $arguments += '--user'
    }

    if ($Application) {
        $arguments += @('--app', $Application)
    }

    if ($Visibility) {
        $arguments += @('--visibility', $Visibility)
    }

    if ($Repos) {
        $arguments += @('--repos', ($Repos -join ','))
    }

    if ($NoReposSelected) {
        $arguments += '--no-repos-selected'
    }

    $extra = @{}
    if ($PSCmdlet.ParameterSetName -eq 'Value') {
        $extra['StdIn'] = $Value
    }

    $activity = if ($PSCmdlet.ParameterSetName -eq 'Value') { "Setting secret $Name" } else { "Setting secrets from $EnvFile" }
    Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $Repository @extra | Out-Null
}
