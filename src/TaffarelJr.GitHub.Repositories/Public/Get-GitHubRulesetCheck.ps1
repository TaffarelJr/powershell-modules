function Get-GitHubRulesetCheck {
    <#
    .SYNOPSIS
        Returns every rule that would apply to a branch.
    .DESCRIPTION
        Calls GitHub's REST API directly
        (repos/OWNER/REPO/rules/branches/BRANCH) - gh's own ruleset check
        prints a display-only summary, with no --json support. The branch
        name is URL-encoded, so one with a # in it is not read as a
        fragment and answered for another branch.
    .PARAMETER Branch
        The branch to check, or a branch object or hashtable with a Name.
        A blank one, and an object with no Name, are refused.
    .PARAMETER Repository
        The repository to check against, as OWNER/REPO, HOST/OWNER/REPO,
        or a URL, or a repository object such as one a listing returned.
        Omit it to use the current directory's repository. A -Repository
        given as $null throws.
    .PARAMETER Hostname
        The GitHub host to ask, for GitHub Enterprise, as a bare host name
        such as ghe.example.com - no scheme, port, or path. A host in
        -Repository says the same; the two must agree. An empty value is
        refused; leave it out for gh's default host.
    .INPUTS
        System.Object
        A branch name, or an object or hashtable with a Name property, such
        as one a branch listing returned.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per applying rule - Type, Parameters, RulesetId,
        RulesetSourceType, RulesetSource.
    .EXAMPLE
        Get-GitHubRulesetCheck -Branch 'main' -Repository 'OWNER/REPO'

        Lists the rules that apply to the main branch of OWNER/REPO.
    .EXAMPLE
        'main', 'release' | Get-GitHubRulesetCheck

        Lists the rules that apply to each branch of the current
        directory's repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Get-GitHubRuleset
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('Name')]
        [AllowEmptyString()]
        [object]$Branch,

        [object]$Repository,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $named = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $place = ConvertTo-GitHubApiRepository -Repository $named -Hostname $Hostname
            $api = @{}
            if ($place.Hostname) {
                $api['Hostname'] = $place.Hostname
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
            $branchName = ConvertTo-GitHubBranchName -Branch $Branch
            $branchSegment = [uri]::EscapeDataString($branchName)
            $endpoint = "repos/$($place.Path)/rules/branches/${branchSegment}?per_page=100"
            $rules = @(Invoke-GitHubApi -Endpoint $endpoint -Paginate @api)
            return ConvertTo-PascalCaseObject -InputObject $rules
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
