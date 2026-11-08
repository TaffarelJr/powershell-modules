function Format-GitHubPullRequestTarget {
    <#
    .SYNOPSIS
        Returns the pull request a change acts on, as -WhatIf and -Confirm
        name it.
    .DESCRIPTION
        A number reads as #12, prefixed with the repository when one was
        given: o/r pull request #12. A URL names its own repository. The
        current branch's pull request says which repository it is looked
        for in, when one was given. The repository is named by
        Format-GitHubRepositoryName, so it reads the same however it was
        given, and any credential a URL carried is left out; so is one in a
        branch name, which Hide-UrlCredential hides.
    .PARAMETER Target
        What Resolve-GitHubPullRequestTarget returned.
    .PARAMETER Repository
        The caller's -Repository, already resolved to text; empty when it
        was left out.
    .OUTPUTS
        The pull request, as a person would write it: such as
        'o/r pull request #12', 'ghe.example.com/o/r pull request #12', or
        'pull request feature/x'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Target,

        [string]$Repository
    )

    $origin = ''
    if ($Repository) {
        $origin = Format-GitHubRepositoryName -Repository $Repository
    }

    if ($Target.Arguments.Count -eq 0) {
        if ($origin) {
            return "$($Target.Name) in $origin"
        }

        return $Target.Name
    }

    $operand = $Target.Arguments[0]
    if ($operand -match '^https?://[^/\s]+/[^/\s]+/[^/\s]+/pull/(?<number>[0-9]+)') {
        $number = $Matches['number']
        $urlOrigin = Format-GitHubRepositoryName -Repository $operand
        return "$urlOrigin pull request #$number"
    }

    $shownOperand = Hide-UrlCredential -Text $operand
    $name = if ($operand -match '^[0-9]+$') { "pull request #$operand" } else { "pull request $shownOperand" }
    if ($origin) {
        return "$origin $name"
    }

    return $name
}
