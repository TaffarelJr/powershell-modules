function Format-GitHubTarget {
    <#
    .SYNOPSIS
        Returns the target -WhatIf and -Confirm name for a change: the
        place it is made in, and the item there.
    .DESCRIPTION
        The place is the repository, named by Format-GitHubRepositoryName -
        so a credential in a URL is never shown - followed by an
        environment of it (shown through Hide-UrlCredential, as it is text
        the caller gave); or an organization, or the current user, instead
        of a repository. The application and the item follow, so a secret
        reads like 'o/r environment prod secret TOKEN'. With no place given,
        an item or an environment stands alone, as it is in the current
        directory's repository: 'label bug'; with neither, the target is
        "the current directory's repository".
    .PARAMETER Repository
        The repository reference, or a repository object; empty for the
        current directory's.
    .PARAMETER Environment
        The environment of that repository, if any.
    .PARAMETER Organization
        The organization the change is made in, if any.
    .PARAMETER User
        Names the current user as the place.
    .PARAMETER Application
        The application a secret belongs to, if any.
    .PARAMETER Item
        What in that place is changed, such as 'label bug'.
    .OUTPUTS
        The target text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Repository,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Environment,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Organization,

        [switch]$User,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$Application,

        [string]$Item
    )

    $parts = @("the current directory's repository")
    if ($Environment -or $Item) {
        $parts = @()
    }

    if ($Repository) {
        $parts = @(Format-GitHubRepositoryName -Repository $Repository)
    }

    if ($Environment) {
        $parts += "environment $(Hide-UrlCredential -Text $Environment)"
    }

    if ($Organization) {
        $parts = @("organization $Organization")
    }

    if ($User) {
        $parts = @('the current user')
    }

    if ($Application) {
        $parts += $Application.ToLowerInvariant()
    }

    if ($Item) {
        $parts += $Item
    }

    return $parts -join ' '
}
