function Add-GitHubActionsCommandFile {
    <#
    .SYNOPSIS
        Appends one name/value pair to a command file, in the heredoc
        form GITHUB_OUTPUT, GITHUB_ENV, and GITHUB_STATE all share.
    .DESCRIPTION
        Not exported. A random delimiter per call, rather than a fixed
        one, is what lets -Value safely contain its own newlines - a
        plain NAME=VALUE line cannot.
    .PARAMETER Path
        The command file to append to - $env:GITHUB_OUTPUT,
        $env:GITHUB_ENV, or $env:GITHUB_STATE.
    .PARAMETER Name
        The variable name.
    .PARAMETER Value
        The value. Written exactly as given; never escaped, since the
        heredoc form has no character it must avoid.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    $delimiter = "ghadelimiter_$([guid]::NewGuid())"
    $text = ("$Name<<$delimiter", $Value, $delimiter -join "`n") + "`n"
    [System.IO.File]::AppendAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
}
