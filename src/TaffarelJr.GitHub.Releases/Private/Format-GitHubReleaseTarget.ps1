function Format-GitHubReleaseTarget {
    <#
    .SYNOPSIS
        Returns the release a change acts on, as -WhatIf and -Confirm name
        it.
    .DESCRIPTION
        The tag, prefixed with the repository when the release or the
        caller names one: o/r release v1.0.0, the repository named by
        Format-GitHubRepositoryName and the tag run through
        Hide-UrlCredential, so a credential in a URL is never shown.
        Without a repository it is the current directory's repository's
        release, and reads release v1.0.0.
    .PARAMETER Tag
        The release's tag.
    .PARAMETER Repository
        The repository the release is in, as a reference or a repository
        object; empty for the current directory's.
    .OUTPUTS
        The release, as a person would write it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Tag,

        [AllowNull()]
        [object]$Repository
    )

    $shownTag = Hide-UrlCredential -Text $Tag
    if ($Repository) {
        return "$(Format-GitHubRepositoryName -Repository $Repository) release $shownTag"
    }

    return "release $shownTag"
}
