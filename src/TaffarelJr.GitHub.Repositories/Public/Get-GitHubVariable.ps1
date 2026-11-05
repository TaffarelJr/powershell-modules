function Get-GitHubVariable {
    <#
    .SYNOPSIS
        Returns one Actions variable by name, or every variable at a
        repository, environment, or organization level.
    .DESCRIPTION
        Each variable says where it was read from, in note properties
        Set-GitHubVariable and Remove-GitHubVariable read from the
        pipeline: Repository for a repository's variable, Repository and
        Environment for an environment's, Organization for an
        organization's. Repository is $null when the current directory's
        repository was read. A repository named by a URL that carries a
        credential is kept with the credential hidden, since the object is
        printed.

        One scope at a time: -Environment and -Organization refuse each
        other. Needs gh 2.53 or later, which reports a variable's
        CreatedAt.
    .PARAMETER Name
        The variable to return. Omit it to list them all; a blank one is
        refused.
    .PARAMETER Environment
        Reads a deployment environment's variables instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Reads an organization's variables instead of a repository's: an
        organization name, letters, digits, and dashes. Refuses
        -Repository.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object such as one a listing returned. Omit it to use
        the current directory's repository. A -Repository given as $null
        throws.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        With -Name, one object: Name, Value, CreatedAt, UpdatedAt,
        Visibility, NumSelectedRepos, SelectedReposURL, and the note
        properties above. Without, one such object per variable.
    .EXAMPLE
        Get-GitHubVariable -Name 'DEPLOY_ENV' -Repository 'OWNER/REPO'

        Returns the repository variable DEPLOY_ENV, with its value.
    .EXAMPLE
        Get-GitHubVariable -Organization 'my-org'

        Lists the organization's variables.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubVariable
    .LINK
        Remove-GitHubVariable
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Environment is blank: give the environment's name, or leave it out.")]
        [string]$Environment,

        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($PSBoundParameters.ContainsKey('Name') -and [string]::IsNullOrWhiteSpace($Name)) {
            throw '-Name was given but is blank, so it would list every variable. Give a value, or leave -Name off.'
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $resolve = @{
            CommandLine = $PSBoundParameters
            Bound       = $PSBoundParameters
            Kind        = 'variable'
        }
        Resolve-GitHubSecretScope @resolve | Out-Null
        $fields = 'createdAt,name,numSelectedRepos,selectedReposURL,updatedAt,value,visibility'
        $subcommand = if ($Name) { 'get' } else { 'list' }
        $arguments = @('variable', $subcommand, '--json', $fields)
        $scope = [ordered]@{}
        if ($Environment) {
            $arguments += "--env=$Environment"
            $scope['Repository'] = $reference
            $scope['Environment'] = $Environment
        }
        elseif ($Organization) {
            $arguments += "--org=$Organization"
            $scope['Organization'] = $Organization
        }
        else {
            $scope['Repository'] = $reference
        }

        if ($Name) {
            $arguments += @('--', $Name)
        }

        $activity = if ($Name) { "Reading variable $Name" } else { 'Listing variables' }
        $out = Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $reference
        $variables = @(ConvertFrom-GitHubJson -Lines $out)
        return Add-GitHubScopeProperty -InputObject $variables -Scope $scope
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
