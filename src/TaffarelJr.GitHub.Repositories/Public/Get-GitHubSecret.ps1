function Get-GitHubSecret {
    <#
    .SYNOPSIS
        Returns the secrets defined at a repository, environment,
        organization, or user level - names and metadata, never values.
    .DESCRIPTION
        GitHub never returns a secret's value; this lists what exists so
        a caller can decide whether to set one.
    .PARAMETER Environment
        Lists a deployment environment's secrets instead of the
        repository's own.
    .PARAMETER Organization
        Lists an organization's secrets instead of a repository's.
    .PARAMETER User
        Lists the current user's Codespaces secrets.
    .PARAMETER Application
        Lists the secrets of one application only: actions, agents,
        codespaces, or dependabot.
    .PARAMETER Repository
        The repository to list, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per secret - Name, UpdatedAt, Visibility,
        NumSelectedRepos, SelectedReposURL - always an array.
    #>
    param(
        [string]$Environment,

        [string]$Organization,

        [switch]$User,

        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [string]$Repository
    )

    $arguments = @('secret', 'list', '--json', 'name,numSelectedRepos,selectedReposURL,updatedAt,visibility')
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

    $out = Invoke-GitHubCommand -Activity 'Listing secrets' -Arguments $arguments -Repository $Repository
    $secrets = ConvertFrom-GitHubJson -Lines $out
    return , @($secrets)
}
