function Format-GitHubItemTarget {
    <#
    .SYNOPSIS
        Names what a call acts on, for a -WhatIf or -Confirm message: the
        repository, with any credential it carried removed, then the item.
    .DESCRIPTION
        The repository is named by Core's Format-GitHubRepositoryName, so a
        token in a URL is never shown, and the same repository reads the
        same whether it was given as OWNER/REPO, a URL, or an object. The
        item runs through Hide-UrlCredential, as it may hold a name the
        caller gave. With no repository - gh then acts in the current
        directory's - the item is named alone; with no item, the repository
        is, and "the current directory's repository" when there is none
        either.
    .PARAMETER Repository
        The repository reference; $null or empty for the current
        directory's.
    .PARAMETER Item
        What is acted on in the repository, such as 'workflow ci.yml', with
        any credential in it hidden. Leave it out to name the repository
        itself.
    .OUTPUTS
        The text to show.
    .EXAMPLE
        Format-GitHubItemTarget -Repository 'https://x:ghs_abc@github.com/o/r' -Item 'workflow run 5'

        Gives 'o/r workflow run 5'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Repository,

        [string]$Item
    )

    $name = ''
    if ($Repository) {
        $name = Format-GitHubRepositoryName -Repository $Repository
    }

    if (-not $Item) {
        if ($name) {
            return $name
        }

        return "the current directory's repository"
    }

    $shownItem = Hide-UrlCredential -Text $Item
    if ($name) {
        return "$name $shownItem"
    }

    return $shownItem
}
