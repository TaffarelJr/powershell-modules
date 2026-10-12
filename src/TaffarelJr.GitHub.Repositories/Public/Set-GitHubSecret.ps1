function Set-GitHubSecret {
    <#
    .SYNOPSIS
        Creates or updates a secret at a repository, environment,
        organization, or user level.
    .DESCRIPTION
        The value travels to gh on standard input, never as an argument,
        so it cannot appear in a failure message or a process listing.
        gh encrypts it locally before sending it to GitHub, and drops any
        line breaks from the end of the value. An empty value is refused.

        Give the value as text with -Value, or as a SecureString with
        -SecureValue to keep it out of a script's text and history, or
        set many at once from a dotenv file with -EnvFile.

        One scope at a time: -Environment, -Organization, and -User each
        refuse the others, and -Organization and -User refuse -Repository.
        A secret piped in from Get-GitHubSecret is set by its Name where it
        was listed from - its Repository, Environment, Organization, or
        User, its Application, and an organization secret's Visibility.
        A scope given here wins over the piped one, so a listed name can be
        set elsewhere on purpose; a -Repository naming the piped secret's
        own repository keeps its environment and its host. -EnvFile takes
        no piped input: name its scope with the parameters.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The secret's name: letters, digits, and underscores, not starting
        with a digit or with GITHUB_. GitHub stores it in upper case.
    .PARAMETER Value
        The secret's value, as text. A value typed as a literal on the
        command line lands in PSReadLine's history and in any transcript:
        prefer -SecureValue.
    .PARAMETER SecureValue
        The secret's value, as a SecureString.
    .PARAMETER EnvFile
        A dotenv file whose every entry is set as a secret, instead of one
        -Name/-Value pair. A relative path is taken from the current
        location. gh parses it, by its own dotenv rules: in an unquoted or
        double-quoted value, $NAME and ${NAME} are replaced by an earlier
        entry or by a variable of gh's environment - so X=$GH_TOKEN would
        store the caller's token - and an unquoted value ends at ' #'. A
        single-quoted value is taken literally, so single-quote any value
        holding $, #, or a backslash. A name given twice keeps its last
        value. gh reads only UTF-8: a file starting with a UTF-8
        byte-order mark (which Windows PowerShell's Set-Content -Encoding
        UTF8 writes) or a UTF-16 one is refused before gh is called; save
        it as UTF-8 without one.
    .PARAMETER Environment
        Sets a deployment environment's secret instead of the
        repository's own. A blank one is refused.
    .PARAMETER Organization
        Sets an organization's secret instead of a repository's: an
        organization name, letters, digits, and dashes.
    .PARAMETER User
        Sets a Codespaces secret for the current user, as gh's --user.
    .PARAMETER Application
        Sets the secret for one application only: actions, agents,
        codespaces, or dependabot. agents needs gh 2.93 or later. Refused
        with an environment - given here or piped in - whose secrets are
        always Actions'; beside -Environment or -User, a piped secret's
        actions Application is dropped rather than refused. Any other
        application with -User throws (the user's secrets are always
        Codespaces'), as does a piped one with -Environment. A piped user
        secret (codespaces) set with -Repository or -Organization keeps its
        own application.
    .PARAMETER Visibility
        Which repositories can use an organization secret: all, private,
        or selected; only for an organization's secret. selected needs
        -Repos or -NoReposSelected, and all or private refuse them.
        Omitted, gh makes it private, so a piped organization secret (and
        only an organization's, not a user's) keeps
        an all or private Visibility it was listed with; one listed
        selected throws unless -Repos, -NoReposSelected, or -Visibility
        says how to share it, since gh cannot keep its selection.
        -Repos and -NoReposSelected alone make it selected.
    .PARAMETER Repos
        The repositories that can use an organization or user secret;
        only for those. Refuses -NoReposSelected, a blank name, and an
        empty list.
    .PARAMETER NoReposSelected
        Lets no repository use an organization secret; only for that.
        Refuses -Repos. Needs gh 2.75 or later.
    .PARAMETER Repository
        The repository to set it on, in [HOST/]OWNER/REPO form or as a URL,
        or a repository object. Omit it to use the current directory's
        repository; in a clone with several remotes gh then refuses, so
        name it there (gh 2.66 or later; an older gh picks a remote
        itself, preferring the default repository). A -Repository given
        as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSObject
        A secret from Get-GitHubSecret: its Name, Environment,
        Organization, User, Application, and Repository properties are
        bound, and an organization secret's Visibility is kept.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-GitHubSecret -Name 'NUGET_API_KEY' -Value $env:NUGET_API_KEY `
            -Repository 'OWNER/REPO'

        Sets the repository secret NUGET_API_KEY on OWNER/REPO.
    .EXAMPLE
        $key = Read-Host -AsSecureString -Prompt 'NuGet API key'
        Set-GitHubSecret -Name 'NUGET_API_KEY' -SecureValue $key `
            -Organization 'org' -Repos 'a', 'b'

        Sets an organization secret that only the repositories a and b
        can use, without the key ever appearing as text.
    .EXAMPLE
        Set-GitHubSecret -EnvFile ./secrets.env -Repository 'OWNER/REPO'

        Sets every entry of the dotenv file as a secret of OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubSecret
    .LINK
        Remove-GitHubSecret
    #>
    [CmdletBinding(DefaultParameterSetName = 'Value', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubSecretOrVariableName -Name $_ -Kind secret })]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'Value')]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory, ParameterSetName = 'Secure')]
        [securestring]$SecureValue,

        [Parameter(Mandatory, ParameterSetName = 'EnvFile')]
        [string]$EnvFile,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [AllowEmptyString()]
        [ValidatePattern('\S', ErrorMessage = "-Environment is blank: give the environment's name, or leave it out.")]
        [string]$Environment,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [switch]$User,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'EnvFile')]
        [ValidateSet('actions', 'agents', 'codespaces', 'dependabot')]
        [string]$Application,

        [ValidateSet('all', 'private', 'selected')]
        [string]$Visibility,

        [string[]]$Repos,

        [switch]$NoReposSelected,

        [Parameter(ParameterSetName = 'Value', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Secure', ValueFromPipelineByPropertyName)]
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
                throw '-Repos was given no repositories, so the secret would not be limited to the repositories' +
                ' meant. Give a value, or leave -Repos off.'
            }

            $blankRepos = @($Repos | Where-Object { [string]::IsNullOrWhiteSpace($_) })
            if ($reposGiven -and ($null -eq $Repos -or $blankRepos.Count -gt 0)) {
                throw '-Repos was given a blank name, so the secret would not be limited to the repositories meant.' +
                ' Give a value, or leave -Repos off.'
            }

            if ($Repos -and $NoReposSelected) {
                throw '-Repos and -NoReposSelected cannot be used together: one lets those repositories use the' +
                ' secret, the other lets none. Give only one.'
            }

            if ($Visibility -and $Environment) {
                throw '-Visibility and -Environment cannot be used together: only an organization''s secret has a' +
                ' visibility. Give only one.'
            }

            $restricted = $reposGiven -or $NoReposSelected
            if ($Visibility -eq 'selected' -and -not $restricted) {
                throw '-Visibility selected works only with -Repos or -NoReposSelected: gh needs to know which' +
                ' repositories may use the secret. Give -Repos too, or leave -Visibility off.'
            }

            if ($Visibility -and $Visibility -ne 'selected' -and $restricted) {
                $list = '-NoReposSelected'
                if ($reposGiven) {
                    $list = '-Repos'
                }

                throw "-Visibility $($Visibility.ToLowerInvariant()) and $list cannot be used together:" +
                " $list makes the secret selected. Give only one."
            }
            $empty = 'The value is empty - give the secret a value, or delete it with Remove-GitHubSecret.'
            if ($PSBoundParameters.ContainsKey('Value') -and $Value.Length -eq 0) {
                throw $empty
            }

            if ($PSBoundParameters.ContainsKey('SecureValue') -and $SecureValue.Length -eq 0) {
                throw $empty
            }

            $resolve = @{
                CommandLine = $commandLine
                Bound       = $commandLine
                Kind        = 'secret'
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
                CommandLine = $commandLine
                Bound       = $bound
                Kind        = 'secret'
                Piped       = $listed
                Item        = "Secret $Name"
            }
            $scope = Resolve-GitHubSecretScope @resolve
            if ($Visibility -and -not $scope.Organization) {
                throw '-Visibility works only with -Organization: only an organization''s secret has a visibility.' +
                ' Give -Organization too, or leave -Visibility off.'
            }

            if ($NoReposSelected -and -not $scope.Organization) {
                throw '-NoReposSelected works only with -Organization: only an organization''s secret can be kept' +
                ' from every repository. Give -Organization too, or leave -NoReposSelected off.'
            }

            if ($Repos -and -not ($scope.Organization -or $scope.User)) {
                throw '-Repos works only with -Organization or -User: only their secrets are limited to some' +
                ' repositories. Give -Organization or -User too, or leave -Repos off.'
            }

            $arguments = @('secret', 'set')
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

            $shared = $Visibility
            $fromListing = -not $shared -and -not $restricted -and $scope.Organization -and $null -ne $listed
            $fromListing = $fromListing -and $listed.PSObject.Properties['Organization'] -and $listed.Organization
            if ($fromListing -and $listed.PSObject.Properties['Visibility']) {
                $shared = "$($listed.Visibility)"
                if ($shared -eq 'selected') {
                    throw "Secret $Name is shared with selected repositories: give -Repos (or -NoReposSelected)" +
                    ' to keep it limited, or give -Visibility.'
                }
            }

            if ($shared -in 'all', 'private', 'selected') {
                $arguments += @('--visibility', $shared.ToLowerInvariant())
            }

            if ($Repos) {
                $arguments += @('--repos', ($Repos -join ','))
            }

            if ($NoReposSelected) {
                $arguments += '--no-repos-selected'
            }

            $shown = @{
                Repository   = $scope.Repository
                Environment  = $scope.Environment
                Organization = $scope.Organization
                User         = $scope.User
                Application  = $scope.Application
                Item         = "secret $Name"
            }
            $action = 'Set secret'
            if ($file) {
                $shown.Remove('Item')
                $action = "Set secrets from $(Hide-UrlCredential -Text $EnvFile)"
            }

            $target = Format-GitHubTarget @shown
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $invoke = @{
                Repository = $scope.Repository
            }
            if ($file) {
                $invoke['Activity'] = "Setting secrets from $EnvFile"
                $invoke['Arguments'] = $arguments + @('--env-file', $file)
            }
            else {
                $invoke['Activity'] = "Setting secret $Name"
                $invoke['Arguments'] = $arguments + @('--', $Name)
                $invoke['StdIn'] = $Value
                if ($SecureValue) {
                    $invoke['StdIn'] = ConvertFrom-SecureString -SecureString $SecureValue -AsPlainText
                }
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
