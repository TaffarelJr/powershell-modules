function Get-VisibleLength {
    <#
    .SYNOPSIS
        Returns how many characters of text show on screen,
        not counting its color codes or hyperlink markup.
    .DESCRIPTION
        Not exported. A color code (an SGR escape sequence, with its
        parameters separated by semicolons or colons) and an OSC sequence
        (the markup around a $PSStyle hyperlink, ended by a bell or by
        ESC \) change how text looks but take no room on screen.
        A hyperlink's visible text still counts.
        Every other character counts as one, so wide characters and emoji
        still count as one.
    .PARAMETER Text
        The text to measure.
    #>
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $plain = $Text -replace '\e\[[0-9;:]*m|\e\][^\a\e]*(?:\a|\e\\)', ''
    return $plain.Length
}
