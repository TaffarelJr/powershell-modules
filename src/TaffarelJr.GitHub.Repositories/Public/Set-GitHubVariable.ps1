function Set-GitHubVariable {
    <#
    .SYNOPSIS
        Creates or updates an Actions variable at a repository,
        environment, or organization level.
    .DESCRIPTION
        The value travels to gh on standard input rather than as an
        argument, so a multi-line value or one starting with a dash
        arrives intact. gh drops any line breaks from the end of it.

        One scope at a time: -Environment and -Organization refuse each
        other, and -Organization refuses -Repository. A variable piped in
        from Get-GitHubVariable is set by its Name where it was read from -
        its Repository, Environment, or Organization, and an organization
        variable's Visibility. A scope given here wins over the piped one,
        so a listed name can be set elsewhere on purpose; a -Repository
        naming the piped variable's own repository keeps its environment
        and its host. -EnvFile takes no piped input: name its scope with
        the parameters.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The variable's name: letters, digits, and underscores, not
        starting with a digit or with GITHUB_. GitHub stores it in upper
        case.
    .PARAMETER Value
        The variable's value. An empty one is allowed.
    .PARAMETER EnvFile
        A dotenv file whose every entry is set as a variable, instead of
        one -Name/-Value pair. A relative path is taken from the current
        location. gh parses it, by its own dotenv rules: in an unquoted or
        double-quoted value, $NAME and ${NAME} are replaced by an earlier
        entry or by a variable of gh's environment, and an unquoted value
        ends at ' #'. A single-quoted value is taken literally, so
        single-quote any value holding $, #, or a backslash. A name given
        twice keeps its last value. gh reads only UTF-8: a file starting
        with a UTF-8 byte-order mark (which Windows PowerShell's
        Set-Content -Encoding UTF8 writes) or a UTF-16 one is refused
        before gh is called; save it as UTF-8 without one.
    .PARAMETER Environment
        Sets a deployment environment's variable instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Sets an organization's variable instead of a repository's: an
        organization name, letters, digits, and dashes.
    .PARAMETER Visibility
        Which repositories can use an organization variable: all,
        private, or selected; only for an organization's variable. selected
        needs -Repos, and all or private refuse it. Omitted, gh makes it
        private, so a piped organization variable keeps an all or private
        Visibility it was read with; one read as selected throws unless
        -Repos or -Visibility says how to share it, since gh cannot keep
        its selection. -Repos alone makes it selected.
    .PARAMETER Repos
        The repositories that can use an organization variable; only for
        that. A blank name, and an empty list, are refused.
    .PARAMETER Repository
        The repository to set it on, in [HOST/]OWNER/REPO form or as a URL,
        or a repository object. Omit it to use the current directory's
        repository. A -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSObject
        A variable from Get-GitHubVariable: its Name, Environment,
        Organization, and Repository properties are bound, and an
        organization variable's Visibility is kept.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-GitHubVariable -Name 'DEPLOY_ENV' -Value 'staging' `
            -Repository 'OWNER/REPO'

        Sets the repository variable DEPLOY_ENV on OWNER/REPO.
    .EXAMPLE
        Set-GitHubVariable -EnvFile ./variables.env -Environment 'production'

        Sets every entry of the dotenv file as a variable of the
        production environment of the current directory's repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubVariable
    .LINK
        Remove-GitHubVariable
    #>
    [CmdletBinding(DefaultParameterSetName = 'Value', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubSecretOrVariableName -Name $_ -Kind variable })]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'Value')]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory, ParameterSetName = 'EnvFile')]
        [string]$EnvFile,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Environment is blank: give the environment's name, or leave it out.")]
        [string]$Environment,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [ValidateSet('all', 'private', 'selected')]
        [string]$Visibility,

        [string[]]$Repos,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
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
            $reposGiven = $PSBoundParameters.ContainsKey('Repos')
            if ($reposGiven -and $null -ne $Repos -and $Repos.Count -eq 0) {
                throw '-Repos was given no repositories, so the variable would not be limited to the repositories' +
                ' meant. Give a value, or leave -Repos off.'
            }

            $blankRepos = @($Repos | Where-Object { [string]::IsNullOrWhiteSpace($_) })
            if ($reposGiven -and ($null -eq $Repos -or $blankRepos.Count -gt 0)) {
                throw '-Repos was given a blank name, so the variable would not be limited to the repositories meant.' +
                ' Give a value, or leave -Repos off.'
            }

            if ($Visibility -eq 'selected' -and -not $reposGiven) {
                throw '-Visibility selected works only with -Repos: gh needs to know which repositories may use the' +
                ' variable. Give -Repos too, or leave -Visibility off.'
            }

            if ($Visibility -and $Visibility -ne 'selected' -and $reposGiven) {
                throw "-Visibility $($Visibility.ToLowerInvariant()) and -Repos cannot be used together: -Repos makes" +
                ' the variable selected. Give only one.'
            }

            if ($Visibility -and $Environment) {
                throw '-Visibility and -Environment cannot be used together: only an organization''s variable has a' +
                ' visibility. Give only one.'
            }

            $resolve = @{
                CommandLine = $commandLine
                Bound       = $commandLine
                Kind        = 'variable'
            }
            Resolve-GitHubSecretScope @resolve | Out-Null
            $file = $null
            if ($PSBoundParameters.ContainsKey('EnvFile')) {
                $file = Resolve-GitHubEnvFile -Path $EnvFile
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $listed = $null
            if ($MyInvocation.ExpectingInput) {
                $listed = $_
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
                CommandLine = $commandLine
                Bound       = $bound
                Kind        = 'variable'
                Piped       = $listed
                Item        = "Variable $Name"
            }
            $scope = Resolve-GitHubSecretScope @resolve
            if ($commandLine.ContainsKey('Visibility') -and -not $scope.Organization) {
                throw '-Visibility works only with -Organization: only an organization''s variable has a visibility.' +
                ' Give -Organization too, or leave -Visibility off.'
            }

            if ($commandLine.ContainsKey('Repos') -and -not $scope.Organization) {
                throw '-Repos works only with -Organization: only an organization''s variable is limited to some' +
                ' repositories. Give -Organization too, or leave -Repos off.'
            }

            $arguments = @('variable', 'set')
            if ($scope.Environment) {
                $arguments += "--env=$($scope.Environment)"
            }

            if ($scope.Organization) {
                $arguments += "--org=$($scope.Organization)"
            }

            $shared = $Visibility
            $fromListing = -not $shared -and -not $reposGiven -and $scope.Organization -and $null -ne $listed
            $fromListing = $fromListing -and $listed.PSObject.Properties['Organization'] -and $listed.Organization
            if ($fromListing -and $listed.PSObject.Properties['Visibility']) {
                $shared = "$($listed.Visibility)"
                if ($shared -eq 'selected') {
                    throw "Variable $Name is shared with selected repositories: give -Repos to keep it limited, or" +
                    ' give -Visibility.'
                }
            }

            if ($shared -in 'all', 'private', 'selected') {
                $arguments += @('--visibility', $shared.ToLowerInvariant())
            }

            if ($Repos) {
                $arguments += @('--repos', ($Repos -join ','))
            }

            $shown = @{
                Repository   = $scope.Repository
                Environment  = $scope.Environment
                Organization = $scope.Organization
                Item         = "variable $Name"
            }
            $action = 'Set variable'
            if ($file) {
                $shown.Remove('Item')
                $action = "Set variables from $(Hide-UrlCredential -Text $EnvFile)"
            }

            $target = Format-GitHubTarget @shown
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $invoke = @{
                Repository = $scope.Repository
            }
            if ($file) {
                $invoke['Activity'] = "Setting variables from $EnvFile"
                $invoke['Arguments'] = $arguments + @('--env-file', $file)
            }
            else {
                $invoke['Activity'] = "Setting variable $Name"
                $invoke['Arguments'] = $arguments + @('--', $Name)
                $invoke['StdIn'] = $Value
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
