function Get-GitHubRuleset {
    <#
    .SYNOPSIS
        Returns one ruleset in full, or lists a repository's or
        organization's rulesets.
    .DESCRIPTION
        gh's own ruleset subcommands have no --json support and print a
        lossy, display-only summary - no conditions, no rules, no bypass
        actors. This calls GitHub's REST API directly instead
        (repos/OWNER/REPO/rulesets, .../rulesets/ID, or the organization's
        equivalent) so a caller gets the same full data GitHub's website
        shows, re-cased to PascalCase like every other function here.

        -Organization needs -Id or -List: PowerShell resolves the
        parameters before this function runs, so -Organization alone
        cannot be told what is missing.

        A ruleset piped in from a listing is read where it is defined, by
        its Source and SourceType: from its repository, or from its
        organization, on the host it was listed from - a listing from a
        GitHub Enterprise host gives each ruleset a Hostname note
        property, which -Hostname reads from the pipeline. A -Repository or
        -Organization naming another place throws, since a ruleset id
        exists only where it is defined; a -Repository naming the
        ruleset's own repository keeps its host, and one naming a host is
        compared with the host the ruleset was listed from (gh's default
        host - GH_HOST, else github.com - when the listing named none). A
        Source without a SourceType, or a SourceType without a Source,
        throws. A ruleset defined for a whole enterprise cannot
        be read this way: it is skipped with a warning, and the rest of
        the pipe goes on.
    .PARAMETER Id
        The ruleset to describe in full, by its id.
    .PARAMETER List
        Lists ruleset summaries instead of describing one.
    .PARAMETER Organization
        Reads the organization's own rulesets instead of a repository's:
        an organization name, letters, digits, and dashes.
    .PARAMETER Source
        Where the ruleset is defined - OWNER/REPO or an organization - as
        a listed ruleset's Source reports it.
    .PARAMETER SourceType
        Whether Source is a Repository or an Organization, as a listed
        ruleset's SourceType reports it. An Enterprise one is skipped with
        a warning.
    .PARAMETER IncludeParents
        With -List for a repository, includes rulesets configured at a
        higher level that apply here too, or with -IncludeParents:$false
        leaves them out. GitHub's own default is to include them.
    .PARAMETER Repository
        The repository to read, as OWNER/REPO, HOST/OWNER/REPO, or a URL, or
        a repository object such as one a listing returned. Omit it to use
        the current directory's repository. A -Repository given as $null
        throws. Refuses -Organization.
    .PARAMETER Hostname
        The GitHub host to ask, for GitHub Enterprise, as a bare host name
        such as ghe.example.com - no scheme, port, or path. A host in
        -Repository says the same; the two must agree. Read from a piped
        ruleset's Hostname too, where $null or an empty one means gh's
        default host. Given as a parameter, an empty value is refused;
        leave it out for gh's default host.
    .INPUTS
        System.Management.Automation.PSObject
        A ruleset from a listing, read by its Id, Source, SourceType, and
        Hostname properties.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        With -List: one summary object per ruleset - Id, Name, Target,
        SourceType, Source, Enforcement, NodeId, Links, CreatedAt,
        UpdatedAt, and Hostname when a host was named. Without it: one
        full object, also including Conditions, Rules, BypassActors, and
        CurrentUserCanBypass.
    .EXAMPLE
        Get-GitHubRuleset -List -Repository 'cli/cli' | Get-GitHubRuleset

        Reads every ruleset that applies to cli/cli in full, each from
        where it is defined.
    .EXAMPLE
        Get-GitHubRuleset -List -Organization 'my-org'

        Lists the organization's own rulesets; -Organization needs -List
        or -Id.
    .EXAMPLE
        Get-GitHubRuleset -Id 42 -Organization 'my-org'

        Reads the organization's ruleset 42 in full.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubRulesetCheck
    #>
    [CmdletBinding(DefaultParameterSetName = 'Repository')]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Repository', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Organization', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Source', ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ListRepository')]
        [Parameter(Mandatory, ParameterSetName = 'ListOrganization')]
        [switch]$List,

        [Parameter(Mandatory, ParameterSetName = 'Organization')]
        [Parameter(Mandatory, ParameterSetName = 'ListOrganization')]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubOrganizationName -Name $_ })]
        [string]$Organization,

        [Parameter(Mandatory, ParameterSetName = 'Source', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Repository', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Organization', ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Source,

        [Parameter(Mandatory, ParameterSetName = 'Source', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Repository', ValueFromPipelineByPropertyName)]
        [Parameter(ParameterSetName = 'Organization', ValueFromPipelineByPropertyName)]
        [ValidateSet(
            'Repository',
            'Organization',
            'Enterprise',
            ErrorMessage = "'{0}' is not a ruleset source type: give Repository, Organization, or Enterprise."
        )]
        [string]$SourceType,

        [Parameter(ParameterSetName = 'ListRepository')]
        [switch]$IncludeParents,

        [Parameter(ParameterSetName = 'Repository')]
        [Parameter(ParameterSetName = 'ListRepository')]
        [Parameter(ParameterSetName = 'Organization')]
        [Parameter(ParameterSetName = 'ListOrganization')]
        [object]$Repository,

        [Parameter(ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Hostname
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if ($PSBoundParameters.ContainsKey('Hostname')) {
                Assert-GitHubHostname -Hostname $Hostname | Out-Null
            }

            if ($PSBoundParameters.ContainsKey('Organization') -and $PSBoundParameters.ContainsKey('Repository')) {
                throw '-Organization and -Repository cannot be used together: a ruleset is read from one place -' +
                ' an organization or a repository. Give only one.'
            }

            foreach ($other in 'Repository', 'Organization') {
                if ($PSBoundParameters.ContainsKey('Source') -and $PSBoundParameters.ContainsKey($other)) {
                    throw "-Source and -$other cannot be used together: -Source already names where the ruleset is" +
                    ' defined. Give only one.'
                }
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $commandLineRepository = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $shownRepository = Hide-UrlCredential -Text $commandLineRepository
            $commandLineOrganization = $PSBoundParameters.ContainsKey('Organization')
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $organizationName = $Organization
            $named = $Repository
            $sourceGiven = -not [string]::IsNullOrWhiteSpace($Source)
            if ($SourceType -and $SourceType -ne 'Enterprise' -and -not $sourceGiven) {
                throw '-SourceType works only with -Source: it says what kind of place -Source names.' +
                ' Give -Source too, or leave -SourceType off.'
            }

            if ($sourceGiven -and -not $SourceType) {
                throw '-Source works only with -SourceType: it does not say whether it names a repository or an' +
                ' organization. Give -SourceType too, or leave -Source off.'
            }

            if ($SourceType) {
                $shown = Hide-UrlCredential -Text $Source
                if ($SourceType -eq 'Enterprise') {
                    $skipped = "Ruleset $Id is defined for the enterprise $shown," +
                    ' which cannot be read here: skipped.'
                    Write-Warning $skipped
                    return
                }

                $sameOrganization = [StringComparer]::OrdinalIgnoreCase.Equals($Source, $Organization)
                if ($commandLineOrganization -and -not ($SourceType -eq 'Organization' -and $sameOrganization)) {
                    throw "Ruleset $Id is in $shown, but -Organization names ${Organization}: give one or the other."
                }

                if ($SourceType -eq 'Organization') {
                    if ($commandLineRepository) {
                        throw "Ruleset $Id is in the organization $shown, but -Repository names" +
                        " ${shownRepository}: give one or the other."
                    }

                    $organizationName = $Source
                }
                elseif ($commandLineRepository) {
                    Assert-GitHubSameRepository -Item "Ruleset $Id" -Origin $Source -Repository $commandLineRepository
                    $namedHost = Get-GitHubReferenceHost -Reference $commandLineRepository -Named
                    $listedHost = Get-GitHubReferenceHost -Reference $Source
                    if ($Hostname) {
                        $listedHost = $Hostname.ToLowerInvariant()
                    }

                    if ($namedHost -and $namedHost -ne $listedHost) {
                        throw "Ruleset $Id is in $listedHost/$shown, but -Repository names ${shownRepository}:" +
                        ' give one or the other.'
                    }

                    $named = $commandLineRepository
                }
                else {
                    $named = $Source
                }
            }

            if ($Hostname) {
                Assert-GitHubHostname -Hostname $Hostname | Out-Null
            }

            $server = $Hostname
            if ($organizationName) {
                if ($organizationName -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
                    $shownName = Hide-UrlCredential -Text $organizationName
                    throw "'$shownName' is not an organization name: give letters, digits, and dashes."
                }

                $scope = "orgs/$organizationName"
            }
            else {
                $place = ConvertTo-GitHubApiRepository -Repository $named -Hostname $Hostname
                $scope = "repos/$($place.Path)"
                $server = $place.Hostname
            }

            $api = @{}
            if ($server) {
                $api['Hostname'] = $server
            }

            if (-not $List) {
                $ruleset = Invoke-GitHubApi -Endpoint "$scope/rulesets/$Id" @api
                return ConvertTo-PascalCaseObject -InputObject $ruleset
            }

            $query = 'per_page=100'
            if ($PSBoundParameters.ContainsKey('IncludeParents')) {
                $query += "&includes_parents=$($IncludeParents.IsPresent.ToString().ToLowerInvariant())"
            }

            $rulesets = @(Invoke-GitHubApi -Endpoint "$scope/rulesets?$query" -Paginate @api)
            $summaries = @(ConvertTo-PascalCaseObject -InputObject $rulesets)
            if (-not $server) {
                return $summaries
            }

            return Add-GitHubScopeProperty -InputObject $summaries -Scope ([ordered]@{ Hostname = $server })
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
