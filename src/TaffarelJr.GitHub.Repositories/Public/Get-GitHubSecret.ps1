function Get-GitHubSecret {
    <#
    .SYNOPSIS
        Returns the secrets defined at a repository, environment,
        organization, or user level - names and metadata, never values.
    .DESCRIPTION
        GitHub never returns a secret's value; this lists what exists so
        a caller can decide whether to set one.

        Each secret says where it was listed from, in note properties
        Set-GitHubSecret and Remove-GitHubSecret read from the pipeline:
        Repository and Application for a repository's secret, Repository
        and Environment for an environment's, Organization and
        Application for an organization's, User and Application for the
        user's. Repository is $null when the current directory's
        repository was listed, and Application is gh's default (actions,
        or codespaces for the user) when none was asked for. A repository
        named by a URL that carries a credential is kept with the
        credential hidden, since the object is printed.

        One scope at a time: -Environment, -Organization, and -User each
        refuse the others, and -Organization and -User refuse
        -Repository.
    .PARAMETER Environment
        Lists a deployment environment's secrets instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Lists an organization's secrets instead of a repository's: an
        organization name, letters, digits, and dashes.
    .PARAMETER User
        Lists the current user's Codespaces secrets, as gh's --user.
    .PARAMETER Application
        Lists the secrets of one application only: actions, agents,
        codespaces, or dependabot. agents needs gh 2.93 or later. Refused
        with -Environment, whose secrets are always Actions'.
    .PARAMETER Repository
        The repository to list, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object such as one a listing returned. Omit it to use
        the current directory's repository; in a clone with several
        remotes gh then refuses, so name it there (gh 2.66 or later; an
        older gh picks a remote itself, preferring the default
        repository). A -Repository given as $null throws.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per secret - Name, UpdatedAt, Visibility,
        NumSelectedRepos, SelectedReposURL - and the note properties
        above.
    .EXAMPLE
        Get-GitHubSecret -Repository 'OWNER/REPO'

        Lists the names and metadata of the repository's Actions secrets.
    .EXAMPLE
        Get-GitHubSecret -Organization 'my-org' |
            Where-Object Name -Like 'OLD_*' |
            Remove-GitHubSecret

        Deletes the organization's secrets whose names start with OLD_:
        each piped secret carries its Organization, so it is deleted
        there, not in the current directory's repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubSecret
    .LINK
        Remove-GitHubSecret
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Environment is blank: give the environment's name, or leave it out.")]
        [string]$Environment,

        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [switch]$User,

        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($Environment -and $Application) {
            throw '-Application and -Environment cannot be used together: an environment''s secrets are always' +
            ' Actions''. Give only one.'
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $resolve = @{
            CommandLine = $PSBoundParameters
            Bound       = $PSBoundParameters
            Kind        = 'secret'
        }
        Resolve-GitHubSecretScope @resolve | Out-Null
        $app = 'actions'
        if ($Application) {
            $app = $Application.ToLowerInvariant()
        }
        elseif ($User) {
            $app = 'codespaces'
        }

        $arguments = @('secret', 'list', '--json', 'name,numSelectedRepos,selectedReposURL,updatedAt,visibility')
        $scope = [ordered]@{}
        if ($Environment) {
            $arguments += "--env=$Environment"
            $scope['Repository'] = $reference
            $scope['Environment'] = $Environment
        }
        elseif ($Organization) {
            $arguments += "--org=$Organization"
            $scope['Organization'] = $Organization
            $scope['Application'] = $app
        }
        elseif ($User) {
            $arguments += '--user'
            $scope['User'] = $true
            $scope['Application'] = $app
        }
        else {
            $scope['Repository'] = $reference
            $scope['Application'] = $app
        }

        if ($Application) {
            $arguments += @('--app', $app)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing secrets' -Arguments $arguments -Repository $reference
        $secrets = @(ConvertFrom-GitHubJson -Lines $out)
        return Add-GitHubScopeProperty -InputObject $secrets -Scope $scope
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
