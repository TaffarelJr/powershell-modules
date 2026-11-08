function Format-GitHubIssueTarget {
    <#
    .SYNOPSIS
        Returns how -WhatIf and -Confirm name an issue: its repository and
        number, as a person would write them.
    .DESCRIPTION
        A URL names its own repository. A number is in -Repository, or,
        with none, in the current directory's repository, which the target
        then leaves unnamed. The repository is named by
        Format-GitHubRepositoryName, so it reads the same however it was
        given, and any credential a URL carried is left out.
    .PARAMETER Reference
        The issue as Resolve-GitHubItemReference returned it: its number or
        its URL.
    .PARAMETER Repository
        The repository the caller passes to gh, if any.
    .OUTPUTS
        Such as 'o/r issue #12', 'ghe.example.com/o/r issue #12', or
        'issue #12'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Reference,

        [string]$Repository
    )

    if ($Reference -match '^https?://[^/\s]+/[^/\s]+/[^/\s]+/issues/(?<number>[0-9]+)') {
        $number = $Matches['number']
        $origin = Format-GitHubRepositoryName -Repository $Reference
        return "$origin issue #$number"
    }

    if ($Repository) {
        $origin = Format-GitHubRepositoryName -Repository $Repository
        return "$origin issue #$Reference"
    }

    return "issue #$Reference"
}
