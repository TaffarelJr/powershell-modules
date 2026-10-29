function Remove-GitHubSecret {
    <#
    .SYNOPSIS
        Deletes a secret at a repository, environment, organization, or
        user level.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. A secret
        piped in from Get-GitHubSecret is deleted by its Name where it was
        listed from - its Repository, Environment, Organization, or User,
        and its Application - so an organization's secret is deleted from
        the organization, not from the current directory's repository. A
        scope given here as a parameter must name the place the piped
        secret lives in - its repository (on its own host; one listed
        without a host is on gh's default host, the one GH_HOST names, else
        github.com), an environment of it, its organization, or the user,
        and its application - or it throws before gh, so a namesake
        elsewhere is not deleted; that includes a -Repository beside a
        secret listed from the current directory's repository. The pipeline
        is read by property name only, so a piped string or hashtable is
        refused rather than taken as a name.

        One scope at a time: -Environment, -Organization, and -User each
        refuse the others, and -Organization and -User refuse
        -Repository.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The secret's name: letters, digits, and underscores, not starting
        with a digit or with GITHUB_.
    .PARAMETER Environment
        Deletes a deployment environment's secret instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Deletes an organization's secret instead of a repository's: an
        organization name, letters, digits, and dashes.
    .PARAMETER User
        Deletes a Codespaces secret of the current user, as gh's --user.
    .PARAMETER Application
        Deletes the secret of one application only: actions, agents,
        codespaces, or dependabot. agents needs gh 2.93 or later. Refused
        with an environment - given here or piped in - whose secrets are
        always Actions'; beside -Environment or -User, a piped secret's
        actions Application is dropped rather than refused. Any other
        application with -User throws, and so does an -Application other
        than a piped secret's own.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current
        directory's repository; in a clone with several remotes gh then
        refuses, so name it there (gh 2.66 or later; an older gh picks a
        remote itself, preferring the default repository). A -Repository
        given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSObject
        A secret from Get-GitHubSecret, read by its Name, Environment,
        Organization, User, Application, and Repository properties.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubSecret -Name 'NUGET_API_KEY' -Repository 'OWNER/REPO'

        Deletes the repository secret NUGET_API_KEY from OWNER/REPO.
    .EXAMPLE
        Remove-GitHubSecret -Name 'DEPLOY_KEY' -Environment 'production' `
            -Repository 'OWNER/REPO'

        Deletes the production environment's DEPLOY_KEY secret.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubSecret
    .LINK
        Set-GitHubSecret
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubSecretOrVariableName -Name $_ -Kind secret })]
        [string]$Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Environment is blank: give the environment's name, or leave it out.")]
        [string]$Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$User,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            Resolve-GitHubRepositoryArgument -Value $Repository -Given $given | Out-Null
            $commandLine = [hashtable]::new($PSBoundParameters, [StringComparer]::OrdinalIgnoreCase)
            $commandLine.Remove('WhatIf')
            $commandLine.Remove('Confirm')
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $piped = $null
            if ($MyInvocation.ExpectingInput) {
                $piped = $_
            }

            $current = [ordered]@{
                Repository   = $Repository
                Environment  = $Environment
                Organization = $Organization
                User         = $User.IsPresent
                Application  = $Application
            }
            $bound = @{}
            foreach ($key in $current.PSBase.Keys) {
                if ($current[$key]) {
                    $bound[$key] = $current[$key]
                }
            }
            $resolve = @{
                CommandLine       = $commandLine
                Bound             = $bound
                Kind              = 'secret'
                Piped             = $piped
                Strict            = $true
                Item              = "Secret $Name"
            }
            $scope = Resolve-GitHubSecretScope @resolve
            $shown = @{
                Repository   = $scope.Repository
                Environment  = $scope.Environment
                Organization = $scope.Organization
                User         = $scope.User
                Application  = $scope.Application
                Item         = "secret $Name"
            }
            $target = Format-GitHubTarget @shown
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete secret')) {
                return
            }

            $arguments = @('secret', 'delete')
            if ($scope.Environment) {
                $arguments += "--env=$($scope.Environment)"
            }

            if ($scope.Organization) {
                $arguments += "--org=$($scope.Organization)"
            }

            if ($scope.User) {
                $arguments += '--user'
            }

            if ($scope.Application) {
                $arguments += @('--app', "$($scope.Application)".ToLowerInvariant())
            }

            $arguments += @('--', $Name)
            $invoke = @{
                Activity   = "Deleting secret $Name"
                Arguments  = $arguments
                Repository = $scope.Repository
            }
            Invoke-GitHubCommand @invoke | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
