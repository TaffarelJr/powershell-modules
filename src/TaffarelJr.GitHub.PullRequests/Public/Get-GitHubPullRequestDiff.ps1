function Get-GitHubPullRequestDiff {
    <#
    .SYNOPSIS
        Returns a pull request's diff, or just the names of the files it
        changes.
    .DESCRIPTION
        The diff is text for reading, line by line, never colored. It is
        not byte-exact: a carriage return at the end of a changed line is
        lost, and a byte that is not UTF-8 becomes U+FFFD, so the lines
        saved again may not apply as a patch to a file with CRLF line
        endings or another encoding.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
    .PARAMETER NameOnly
        Returns only the changed files' paths.
    .PARAMETER Patch
        Returns the diff in patch format.
    .PARAMETER Exclude
        Glob patterns, with forward slashes, for files to leave out. A
        blank pattern throws. Needs gh 2.88 or later.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A pull request given by URL
        or object is in the repository it names; one in a different
        repository than this throws.
    .INPUTS
        System.Object
        A pull request: its number, URL, or head branch, or a pull request
        object such as Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        System.String
        The diff's lines, or the file paths, one at a time.
    .EXAMPLE
        Get-GitHubPullRequestDiff -PullRequest 42 -NameOnly `
            -Repository 'OWNER/REPO'

        Returns the paths of the files pull request 42 changes.
    .EXAMPLE
        Get-GitHubPullRequestDiff -PullRequest 42 -Exclude '*.lock'

        Returns the diff of pull request 42 in the current directory's
        repository, leaving out lock files.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [switch]$NameOnly,

        [switch]$Patch,

        [ValidatePattern(
            '\S',
            ErrorMessage = '-Exclude has a blank element, which would leave nothing out.' +
            ' Give patterns, or leave -Exclude out.'
        )]
        [string[]]$Exclude,

        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $resolve = @{
                BoundParameters = $PSBoundParameters
                Repository      = $repositoryReference
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $arguments = @('pr', 'diff') + $target.Arguments + @('--color', 'never')
            if ($NameOnly) {
                $arguments += '--name-only'
            }

            if ($Patch) {
                $arguments += '--patch'
            }

            foreach ($pattern in $Exclude) {
                $arguments += "--exclude=$pattern"
            }

            $command = @{
                Activity   = "Reading the diff of $($target.Name)"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            return Invoke-GitHubCommand @command
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
