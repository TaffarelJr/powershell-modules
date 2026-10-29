function Test-GitHubUrlText {
    <#
    .SYNOPSIS
        Reports whether gh reads a repository reference as a URL rather
        than as [HOST/]OWNER/REPO text.
    .DESCRIPTION
        Not exported. The one definition ConvertTo-GitHubRepositoryReference
        and Split-GitHubRepositoryReference share, so they cannot drift: gh
        (go-gh's git.IsURL) takes text as a URL only when it starts with
        git@ or with one of the schemes https:, http:, ssh:, git:,
        git+ssh:, or git+https:, matched with case. GIT@HOST:... and
        HTTPS://... are therefore text to gh, which it cannot read.
    .PARAMETER Text
        The reference.
    .OUTPUTS
        $true when gh reads the text as a URL.
    #>
    [OutputType([bool])]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    return $Text -cmatch '^(?:git@|(?:https?|ssh|git|git\+ssh|git\+https):)'
}
