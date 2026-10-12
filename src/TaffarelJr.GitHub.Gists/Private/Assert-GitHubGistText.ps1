function Assert-GitHubGistText {
    <#
    .SYNOPSIS
        Throws when a gist file's content is not text GitHub keeps: empty,
        only whitespace, or binary data.
    .DESCRIPTION
        GitHub refuses a gist file whose content is empty or blank. Binary
        means a control character text never holds, as
        Test-GitHubGistBinary has it.
    .PARAMETER Text
        The content.
    .PARAMETER Source
        Where the content came from, for the message: a quoted path, a
        parameter with its quoted value, or -Content. It is shown as it is,
        so a caller hides any URL credential in it first.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Source
    )

    if ($Text -notmatch '\S') {
        throw "$Source is empty or only whitespace, and GitHub refuses a gist file with no content."
    }

    if (Test-GitHubGistBinary -Text $Text) {
        throw "$Source holds binary data, and a gist holds text only."
    }
}
