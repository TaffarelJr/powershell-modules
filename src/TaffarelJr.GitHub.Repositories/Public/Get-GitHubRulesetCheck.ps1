function Get-GitHubRulesetCheck {
    <#
    .SYNOPSIS
        Returns every rule that would apply to a branch.
    .DESCRIPTION
        Calls GitHub's REST API directly, the same way Get-GitHubRuleset
        does - gh's own ruleset check prints a display-only summary,
        with no --json support.
    .PARAMETER Branch
        The branch to check.
    .PARAMETER Repository
        The repository to check against, in [HOST/]OWNER/REPO form. Omit
        it to use the current directory's repository.
    .OUTPUTS
        One object per applying rule - Type, Parameters, RulesetId,
        RulesetSourceType, RulesetSource - always an array.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Branch,

        [string]$Repository
    )

    process {
        $repoSegment = if ($Repository) { $Repository } else { '{owner}/{repo}' }
        $rules = Invoke-GitHubApi -Endpoint "repos/$repoSegment/rules/branches/$Branch"
        $rules = ConvertTo-PascalCaseObject -InputObject $rules
        return , @($rules)
    }
}
