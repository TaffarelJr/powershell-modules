function ConvertTo-GitHubActionsCommandFileText {
    <#
    .SYNOPSIS
        Returns one name/value pair as an entry of a command file, in the
        heredoc form GITHUB_OUTPUT, GITHUB_ENV, and GITHUB_STATE all share.
    .DESCRIPTION
        Not exported. A random delimiter per call, rather than a fixed
        one, is what lets -Value safely contain its own newlines - a
        plain NAME=VALUE line cannot.

        The name cannot be given the same freedom: the runner reads
        everything up to the first = or << as the name, so a name holding
        either, or a line break, would end early and let the rest add
        entries of its own. A name ending in < would do the same, as the
        << written after it would start one character early. Such a name
        throws.

        Only the text is built here, so a caller can refuse a bad name
        before it decides whether to write anything.
    .PARAMETER Name
        The variable name.
    .PARAMETER Value
        The value, written as given; never escaped, since the heredoc
        form has no character it must avoid. A Windows runner reads a
        value that ends in a carriage return back without it, as it takes
        that and the line feed after it for one line end.
    .OUTPUTS
        The entry's text, ending in a line feed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern(
            '^(?!.*<<)(?!.*<\z)(?=[^\r\n]*\S)[^\r\n=]+\z',
            ErrorMessage = "'{0}' is not a name a command file can hold: no line break, '=', '<<', or final '<'.")]
        [ValidatePattern(
            '^[^\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]+\z',
            ErrorMessage = "'{0}' is not a name a command file can hold: it has a control character other than a tab.")]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [ValidatePattern(
            '^[^\x00]*\z',
            ErrorMessage = '-Value holds a NUL character, which is not text: leave it out.')]
        [string]$Value
    )

    $delimiter = "ghadelimiter_$([guid]::NewGuid())"
    return ("$Name<<$delimiter", $Value, $delimiter -join "`n") + "`n"
}
