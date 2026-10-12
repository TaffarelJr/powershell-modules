using namespace System.Collections

function Resolve-GitHubPullRequestTarget {
    <#
    .SYNOPSIS
        Returns the pull request operand gh is to be given, and the name a
        failure message calls it by.
    .DESCRIPTION
        Reads the caller's own bound parameters, so that a pull request
        left out and one given as $null are told apart. Left out means the
        current branch's pull request. Given as $null throws: a lookup that
        came back empty must not quietly mean the current branch's. A
        given one goes through Resolve-GitHubItemReference, which also
        refuses a URL naming another repository than -Repository.

        gh refuses most pr subcommands with --repo and no pull request
        named, so that combination throws here, before gh runs.
    .PARAMETER BoundParameters
        The caller's $PSBoundParameters. Its PullRequest entry is read.
    .PARAMETER Repository
        The caller's -Repository, already resolved to text; empty when it
        was left out.
    .PARAMETER NoBranch
        Refuses a branch name, for a subcommand that takes only a number
        or a URL.
    .PARAMETER AllowCurrent
        Lets -Repository go without a pull request, for a subcommand that
        still looks for the current branch's then.
    .OUTPUTS
        An object with Arguments - the operand, or none for the current
        branch's pull request - and Name: 'pull request 7', or 'the
        current branch's pull request'. Name is for a person to read, so
        any credential in a URL or branch name is hidden in it, and not in
        Arguments, which go to gh.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [IDictionary]$BoundParameters,

        [string]$Repository,

        [switch]$NoBranch,

        [switch]$AllowCurrent
    )

    if ($BoundParameters.PSBase.Keys -notcontains 'PullRequest') {
        if ($Repository -and -not $AllowCurrent) {
            $shownRepository = Format-GitHubRepositoryName -Repository $Repository
            throw "-Repository $shownRepository was given without a pull request, and gh needs one named along with" +
            " --repo. Give -PullRequest, or leave out -Repository to use the current branch's pull request."
        }

        return [PSCustomObject]@{
            Arguments = [string[]]@()
            Name      = "the current branch's pull request"
        }
    }

    $resolve = @{
        Item       = $BoundParameters['PullRequest']
        Kind       = 'PullRequest'
        Repository = $Repository
    }
    $operand = Resolve-GitHubItemReference @resolve
    $shownOperand = Hide-UrlCredential -Text $operand
    if ($NoBranch -and $operand -notmatch '^(?:[0-9]+|https?://\S+)$') {
        throw "'$shownOperand' is not a pull request: give its number or URL, as gh takes no branch name here."
    }

    return [PSCustomObject]@{
        Arguments = [string[]]@($operand)
        Name      = "pull request $shownOperand"
    }
}
