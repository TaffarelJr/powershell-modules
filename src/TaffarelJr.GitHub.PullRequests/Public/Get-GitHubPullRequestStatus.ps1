function Get-GitHubPullRequestStatus {
    <#
    .SYNOPSIS
        Returns the pull requests relevant to the authenticated user in
        a repository: the current branch's, their own, and those awaiting
        their review.
    .DESCRIPTION
        Reads, and changes nothing. CurrentBranch is the pull request of
        the branch checked out in the current directory, or $null when it
        has none; CreatedBy lists the pull requests the signed-in user
        opened, and NeedsReview those that ask for their review.
    .PARAMETER ConflictStatus
        Includes each pull request's merge-conflict status.
    .PARAMETER Property
        The fields to ask gh for, for each pull request, instead of the
        default set - as Get-GitHubPullRequest's -Property, Url and Number
        always added.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object. Omit it to use the current directory's
        repository; given as $null, it throws.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object with CurrentBranch (one pull request, or $null),
        CreatedBy, and NeedsReview (arrays of pull requests).
    .EXAMPLE
        Get-GitHubPullRequestStatus -Repository 'OWNER/REPO'

        Returns the current branch's pull request, the ones the user
        created, and those awaiting their review in OWNER/REPO.
    .EXAMPLE
        $status = Get-GitHubPullRequestStatus
        $status.NeedsReview | Select-Object Number, Title, Url

        Lists the pull requests awaiting the user's review.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [switch]$ConflictStatus,

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
        $fields = Get-GitHubPullRequestField -Property $Property
        $arguments = @('pr', 'status', '--json', $fields)
        if ($ConflictStatus) {
            $arguments += '--conflict-status'
        }

        $command = @{
            Activity   = 'Reading pull request status'
            Arguments  = $arguments
            Repository = $repositoryReference
        }
        $out = Invoke-GitHubCommand @command
        return ConvertFrom-GitHubJson -Lines $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
