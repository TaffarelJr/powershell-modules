function Get-GitHubRuleset {
    <#
    .SYNOPSIS
        Returns one ruleset in full, or lists a repository's or
        organization's rulesets.
    .DESCRIPTION
        gh's own ruleset subcommands have no --json support and print a
        lossy, display-only summary - no conditions, no rules, no bypass
        actors. This calls GitHub's REST API directly instead
        (repos/{repo}/rulesets, .../rulesets/{id}, or the org-scoped
        equivalent) so a caller gets the same full data gh's own web UI
        shows, re-cased to PascalCase like every other function here.
    .PARAMETER Id
        The ruleset to describe in full, by its id.
    .PARAMETER List
        Lists ruleset summaries instead of describing one.
    .PARAMETER Organization
        Reads the organization's own rulesets instead of a repository's.
    .PARAMETER IncludeParents
        With -List, also includes rulesets configured at a higher level
        that apply here too. gh's own default is to include them.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository. Ignored with -Organization.
    .OUTPUTS
        With -List: one summary object per ruleset - Id, Name, Target,
        SourceType, Source, Enforcement - always an array. Without it:
        one full object, also including Conditions, Rules, and
        CurrentUserCanBypass.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'View', ValueFromPipelineByPropertyName)]
        [long]$Id,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [switch]$IncludeParents,

        [string]$Organization,

        [string]$Repository
    )

    process {
        $scope = if ($Organization) { "orgs/$Organization" } else { "repos/$(if ($Repository) { $Repository } else { '{owner}/{repo}' })" }

        if (-not $List) {
            $ruleset = Invoke-GitHubApi -Endpoint "$scope/rulesets/$Id"
            return ConvertTo-PascalCaseObject -InputObject $ruleset
        }

        $endpoint = "$scope/rulesets"
        if ($IncludeParents) {
            $endpoint += '?includes_parents=true'
        }

        $rulesets = Invoke-GitHubApi -Endpoint $endpoint
        $rulesets = ConvertTo-PascalCaseObject -InputObject $rulesets
        return , @($rulesets)
    }
}
