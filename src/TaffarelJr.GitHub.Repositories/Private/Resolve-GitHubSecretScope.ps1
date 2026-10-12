function Resolve-GitHubSecretScope {
    <#
    .SYNOPSIS
        Returns where a secret or variable is to be read, set, or deleted,
        from the values given on the command line and the ones a piped
        object brought, or throws when they name more than one place.
    .DESCRIPTION
        A secret or variable lives in one place: a repository, one of its
        environments, an organization, or (secrets only) the user. An
        environment belongs to its repository.

        Without -Strict (the readers and setters), a scope given on the
        command line wins over a piped object's, so a listed name can be
        applied elsewhere on purpose. A command-line -Environment keeps the
        piped repository, and a command-line -Repository naming the piped
        object's own repository keeps its environment - and its host, so a
        GitHub Enterprise item stays there.

        With -Strict (the removers), a piped object names where it lives
        (its Repository - $null for the current directory's -, its
        Environment in that repository, its Organization, or its User, and
        its Application), and a command-line scope or -Application naming
        anywhere else throws before gh, so a removal cannot hit a namesake.
        A -Repository naming the piped object's own repository keeps its
        environment and its host; one naming a host is compared with the
        piped repository's host, which is gh's default host
        (Get-GitHubReferenceHost) when the listing named none.

        Beside a command-line -Environment or -User (and no command-line
        -Application), a piped Application of actions is dropped: an
        environment's secrets are always Actions', the user's are always
        Codespaces', and Get-GitHubSecret attaches actions to every
        repository and organization secret. Any other application beside
        the user, or a piped one beside an environment, throws.
    .PARAMETER CommandLine
        The values bound on the command line: the function's
        $PSBoundParameters as `begin` sees it.
    .PARAMETER Bound
        This record's values that are not empty: the parameter variables
        as `process` sees them.
    .PARAMETER Kind
        secret or variable, for the messages.
    .PARAMETER Piped
        The piped object, if any.
    .PARAMETER Strict
        Throws when a command-line scope names another place than the
        piped object's.
    .PARAMETER Item
        The item as the messages name it, such as 'Secret A'.
    .OUTPUTS
        An object with Repository (the reference, or $null), Environment,
        Organization, User, and Application.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$CommandLine,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Bound,

        [Parameter(Mandatory)]
        [ValidateSet('secret', 'variable')]
        [string]$Kind,

        [AllowNull()]
        [object]$Piped,

        [switch]$Strict,

        [string]$Item
    )

    $scopeNames = @('Repository', 'Environment', 'Organization', 'User')
    $values = @{}
    foreach ($scopeName in $scopeNames + 'Application') {
        $values[$scopeName] = $null
        if ($Bound.ContainsKey($scopeName)) {
            $values[$scopeName] = $Bound[$scopeName]
        }
    }

    $values['User'] = [bool]$values['User']
    $place = "a $Kind lives in one place - a repository, one of its environments, or an organization"
    if ($Kind -eq 'secret') {
        $place = 'a secret lives in one place - a repository, one of its environments, an organization, or the user'
    }

    $listed = @{}
    $listedApplication = $null
    if ($null -ne $Piped -and $Piped -isnot [string]) {
        $applicationProperty = $Piped.PSObject.Properties['Application']
        if ($applicationProperty -and $applicationProperty.Value) {
            $listedApplication = "$($applicationProperty.Value)"
        }

        foreach ($scopeName in $scopeNames) {
            if ($scopeName -eq 'User' -and $Kind -eq 'variable') {
                continue
            }

            $property = $Piped.PSObject.Properties[$scopeName]
            if ($property -and ($scopeName -eq 'Repository' -or $property.Value)) {
                $listed[$scopeName] = $property.Value
            }
        }
    }

    $fromCommandLine = @($scopeNames | Where-Object { $CommandLine.ContainsKey($_) -and [bool]$CommandLine[$_] })
    $sameRepository = $false
    if ($fromCommandLine -contains 'Repository' -and $listed.ContainsKey('Repository')) {
        $named = ConvertTo-GitHubRepositoryReference -Repository $CommandLine['Repository']
        $shownNamed = Hide-UrlCredential -Text $named
        if ($null -eq $listed['Repository']) {
            if ($Strict) {
                throw "$Item was listed from the current directory's repository, but -Repository names ${shownNamed}:" +
                " leave -Repository off, or list the $Kind with -Repository."
            }
        }
        else {
            $origin = ConvertTo-GitHubRepositoryReference -Repository $listed['Repository']
            $compare = @{
                Item       = $Item
                Origin     = $origin
                Repository = $named
                PassThru   = $true
            }
            if ($Strict) {
                $values['Repository'] = Assert-GitHubSameRepository @compare
                $sameRepository = $true
                $namedHost = Get-GitHubReferenceHost -Reference $named -Named
                $originHost = Get-GitHubReferenceHost -Reference $origin
                if ($namedHost -and $namedHost -ne $originHost) {
                    $shown = Hide-UrlCredential -Text $origin
                    if (-not (Get-GitHubReferenceHost -Reference $origin -Named)) {
                        $shown = "$originHost/$shown"
                    }

                    throw "$Item is in $shown, but -Repository names ${shownNamed}: give one or the other."
                }
            }
            else {
                try {
                    $values['Repository'] = Assert-GitHubSameRepository @compare
                    $sameRepository = $true
                }
                catch {
                    $sameRepository = $false
                }
            }
        }
    }

    $ignoreCase = [StringComparer]::OrdinalIgnoreCase
    $applicationGiven = $CommandLine.ContainsKey('Application') -and $CommandLine['Application']
    if ($Strict -and $applicationGiven -and $listedApplication) {
        if (-not $ignoreCase.Equals($listedApplication, "$($CommandLine['Application'])")) {
            $shownStore = Hide-UrlCredential -Text $listedApplication.ToLowerInvariant()
            throw "$Item is in the $shownStore store, but -Application names" +
            " $("$($CommandLine['Application'])".ToLowerInvariant()): give one or the other."
        }
    }

    if ($Strict -and $fromCommandLine.Count -gt 0 -and $listed.Count -gt 0) {
        foreach ($given in $fromCommandLine) {
            foreach ($where in @($listed.PSBase.Keys)) {
                $sameName = $ignoreCase.Equals("$($listed[$where])", "$($CommandLine[$given])")
                $agrees = switch ($given) {
                    'Repository' {
                        $where -eq 'Repository' -or ($where -eq 'Environment' -and $sameRepository)
                    }
                    'Environment' {
                        $where -eq 'Repository' -or ($where -eq 'Environment' -and $sameName)
                    }
                    'Organization' {
                        $where -eq 'Organization' -and $sameName
                    }
                    'User' {
                        $where -eq 'User'
                    }
                }

                $environmentOfRepository = $given -eq 'Environment' -and $where -eq 'Repository'
                if ($environmentOfRepository -and -not $listed.ContainsKey('Environment')) {
                    $agrees = $false
                }

                if (-not $agrees -and $given -eq $where) {
                    $shownListed = Hide-UrlCredential -Text "$($listed[$where])"
                    $shownGiven = Hide-UrlCredential -Text "$($CommandLine[$given])"
                    throw "$Item is in $($where.ToLowerInvariant()) $shownListed, but -$given names" +
                    " ${shownGiven}: give one or the other."
                }

                if (-not $agrees) {
                    throw "-$given and the piped $Kind's $($where.ToLowerInvariant()) cannot be used together:" +
                    " $place, and a $Kind is deleted where it was listed. Give only one."
                }
            }
        }
    }

    if ($fromCommandLine.Count -gt 0) {
        foreach ($scopeName in $scopeNames) {
            $fromPipe = $Bound.ContainsKey($scopeName) -and -not $CommandLine.ContainsKey($scopeName)
            $keep = ($scopeName -eq 'Repository' -and $CommandLine.ContainsKey('Environment')) -or
            ($scopeName -eq 'Environment' -and $sameRepository)
            if ($fromPipe -and -not $keep) {
                $values[$scopeName] = $null
            }
        }

        $values['User'] = [bool]$values['User']
    }

    $scopes = @('Environment', 'Organization', 'User' | Where-Object { $values[$_] })
    if ($scopes.Count -gt 1) {
        throw "-$($scopes[0]) and -$($scopes[1]) cannot be used together: $place. Give only one."
    }

    $owner = @('Organization', 'User' | Where-Object { $values[$_] })
    if ($null -ne $values['Repository'] -and $owner.Count -gt 0) {
        throw "-$($owner[0]) and -Repository cannot be used together: $place. Give only one."
    }

    $onlyOneApplication = $CommandLine.ContainsKey('Environment') -or [bool]$CommandLine['User']
    $actionsOnly = $onlyOneApplication -and -not $CommandLine.ContainsKey('Application')
    if ($actionsOnly -and "$($values['Application'])" -eq 'actions') {
        $values['Application'] = $null
    }

    $applicationPiped = $values['Application'] -and -not $CommandLine.ContainsKey('Application')
    if ($values['User'] -and $values['Application'] -and "$($values['Application'])" -ne 'codespaces') {
        $clause = ''
        if ($applicationPiped -or -not [bool]$CommandLine['User']) {
            $clause = ', and a piped secret''s Application or User counts too'
        }

        throw "-Application and -User cannot be used together: the user's secrets are always Codespaces'$clause." +
        ' Give only one.'
    }

    if ($values['Environment'] -and $applicationPiped -and $CommandLine.ContainsKey('Environment')) {
        throw "$Item is for $("$($values['Application'])".ToLowerInvariant()), and environments hold only Actions" +
        ' secrets: leave -Environment off, or list an Actions secret.'
    }

    if ($values['Environment'] -and $values['Application']) {
        $fromPipeline = -not ($CommandLine.ContainsKey('Environment') -and $CommandLine.ContainsKey('Application'))
        $clause = ''
        if ($fromPipeline) {
            $clause = ', and a piped secret''s Application or Environment counts too'
        }

        throw "-Application and -Environment cannot be used together: an environment's secrets are always" +
        " Actions'$clause. Give only one."
    }

    return [PSCustomObject]@{
        Repository   = ConvertTo-GitHubRepositoryReference -Repository $values['Repository']
        Environment  = $values['Environment']
        Organization = $values['Organization']
        User         = $values['User']
        Application  = $values['Application']
    }
}
