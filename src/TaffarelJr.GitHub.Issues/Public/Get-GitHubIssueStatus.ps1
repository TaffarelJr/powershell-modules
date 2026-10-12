function Get-GitHubIssueStatus {
    <#
    .SYNOPSIS
        Returns the issues relevant to the authenticated user in a
        repository: issues assigned to them, created by them, and
        mentioning them.
    .DESCRIPTION
        Each issue carries the same fields as Get-GitHubIssue's default;
        see it for what is left out and how -Property changes that.
    .PARAMETER Property
        The fields to return for each issue, spelled as gh spells them or
        in PascalCase. number and url always come back too. Omit it for
        the default set, which needs gh 2.94 or later.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object with Assigned, CreatedBy, and Mentioned - each an
        array of issues.
    .EXAMPLE
        Get-GitHubIssueStatus -Repository OWNER/REPO

        Returns the issues of OWNER/REPO assigned to the authenticated user,
        created by them, and mentioning them.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Get-GitHubIssue
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [string[]]$Property,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $fields = Get-GitHubIssueField -Property $Property
        $invocation = @{
            Activity   = 'Reading issue status'
            Arguments  = @('issue', 'status', '--json', $fields)
            Repository = $repositoryReference
        }
        $out = Invoke-GitHubCommand @invocation
        return ConvertFrom-GitHubJson -Lines $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
