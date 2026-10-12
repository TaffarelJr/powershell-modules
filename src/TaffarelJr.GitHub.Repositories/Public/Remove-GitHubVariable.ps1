function Remove-GitHubVariable {
    <#
    .SYNOPSIS
        Deletes an Actions variable at a repository, environment, or
        organization level.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first. A variable
        piped in from Get-GitHubVariable is deleted by its Name where it was
        read from - its Repository, Environment, or Organization - so an
        organization's variable is deleted from the organization, not
        from the current directory's repository. A scope given here as a
        parameter must name the place the piped variable lives in - its
        repository (on its own host; one listed without a host is on gh's
        default host, the one GH_HOST names, else github.com), an
        environment of it, or its organization - or it throws before gh,
        so a namesake elsewhere is not deleted; that includes a -Repository
        beside a variable read from the current directory's repository.
        The pipeline is read by property name only, so a piped string or
        hashtable is refused rather than taken as a name.

        One scope at a time: -Environment and -Organization refuse each
        other, and -Organization refuses -Repository.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The variable's name: letters, digits, and underscores, not
        starting with a digit or with GITHUB_.
    .PARAMETER Environment
        Deletes a deployment environment's variable instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Deletes an organization's variable instead of a repository's: an
        organization name, letters, digits, and dashes.
    .PARAMETER Repository
        The repository to delete it from, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current
        directory's repository. A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSObject
        A variable from Get-GitHubVariable, read by its Name, Environment,
        Organization, and Repository properties.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubVariable -Name 'DEPLOY_ENV' -Repository 'OWNER/REPO'

        Deletes the repository variable DEPLOY_ENV from OWNER/REPO.
    .EXAMPLE
        Get-GitHubVariable -Organization 'my-org' |
            Remove-GitHubVariable -WhatIf

        Shows which of the organization's variables would be deleted,
        without deleting any.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubVariable
    .LINK
        Set-GitHubVariable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubSecretOrVariableName -Name $_ -Kind variable })]
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
                Kind              = 'variable'
                Piped             = $piped
                Strict            = $true
                Item              = "Variable $Name"
            }
            $scope = Resolve-GitHubSecretScope @resolve
            $shown = @{
                Repository   = $scope.Repository
                Environment  = $scope.Environment
                Organization = $scope.Organization
                Item         = "variable $Name"
            }
            $target = Format-GitHubTarget @shown
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete variable')) {
                return
            }

            $arguments = @('variable', 'delete')
            if ($scope.Environment) {
                $arguments += "--env=$($scope.Environment)"
            }

            if ($scope.Organization) {
                $arguments += "--org=$($scope.Organization)"
            }

            $arguments += @('--', $Name)
            $invoke = @{
                Activity   = "Deleting variable $Name"
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
