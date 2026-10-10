function Remove-GitHubSecret {
    <#
    .SYNOPSIS
        Deletes a secret at a repository, environment, organization, or
        user level.
    .PARAMETER Name
        The secret's name.
    .PARAMETER Environment
        Deletes a deployment environment's secret instead of the
        repository's own.
    .PARAMETER Organization
        Deletes an organization's secret instead of a repository's.
    .PARAMETER User
        Deletes a Codespaces secret of the current user.
    .PARAMETER Application
        Deletes the secret of one application only: actions, agents,
        codespaces, or dependabot.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form. Omit
        it to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Name,

        [string]$Environment,

        [string]$Organization,

        [switch]$User,

        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [string]$Repository
    )

    process {
        $arguments = @('secret', 'delete', $Name)
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

        Invoke-GitHubCommand -Activity "Deleting secret $Name" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
