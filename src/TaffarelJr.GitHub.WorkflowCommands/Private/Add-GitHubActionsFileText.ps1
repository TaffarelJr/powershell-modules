function Add-GitHubActionsFileText {
    <#
    .SYNOPSIS
        Appends text, as UTF-8 without a byte order mark, to one of the
        runner's files.
    .DESCRIPTION
        Not exported. Shared by every function that writes one of the
        runner's files, so a failed write names the variable to check.
    .PARAMETER Variable
        The variable naming the file, such as GITHUB_OUTPUT.
    .PARAMETER Path
        The file's full path, as Resolve-GitHubActionsFilePath returns it.
    .PARAMETER Text
        What to append, exactly as given.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Variable,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    try {
        [System.IO.File]::AppendAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        $shownPath = Hide-UrlCredential -Text $Path
        # The reason names the path too, so it is hidden as well; the exception it came from is not passed on,
        # as its message holds the path as it is.
        $reason = $_.Exception.GetBaseException().Message.Replace($Path, $shownPath)
        $shownReason = Hide-UrlCredential -Text $reason
        $message = "Could not write to the file $Variable points at ('$shownPath'): $shownReason"
        throw [System.IO.IOException]::new($message)
    }
}
