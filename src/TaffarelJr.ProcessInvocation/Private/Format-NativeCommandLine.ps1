function Format-NativeCommandLine {
    <#
    .SYNOPSIS
        Returns a command and its arguments as one line PowerShell can read
        back, with every credential a URL carries hidden.
    .DESCRIPTION
        Not exported. Shared by the failure message of Invoke-NativeCommand
        and the verbose line of every call, so both show the same text.

        A word made only of characters PowerShell leaves alone stays bare,
        and every other word - empty, spaced, or holding anything it would
        act on, such as ; $ # @ , { ( or the stop-parsing token - goes in
        single quotes. A quoted command needs the call operator, or it would
        read as a string. Each word is hidden on its own, so an @ in one
        cannot hide another: first its -Mask values, as Hide-MaskedValue
        hides them, then the credential a URL carries.
    .PARAMETER Command
        The command that was or will be run.
    .PARAMETER Arguments
        The arguments it was or will be given.
    .PARAMETER Mask
        Values to hide in every word, as Hide-MaskedValue takes them.
    .OUTPUTS
        The command line, as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Arguments = @(),

        [string[]]$Mask
    )

    $words = foreach ($word in @($Command) + $Arguments) {
        $masked = Hide-MaskedValue -Text $word -Mask $Mask
        $shown = Hide-UrlCredential -Text $masked
        if ($shown -cmatch '^[\w./:\\=+%-][\w./:\\=+%@-]*\z' -and $shown -ne '--%') {
            $shown
        }
        else {
            # PowerShell ends a single-quoted string on a typographic
            # single quote too, so those are doubled like the ASCII one.
            "'" + ($shown -replace "['‘’‚‛]", '$0$0') + "'"
        }
    }

    $call = $words -join ' '
    if ($call.StartsWith("'")) {
        $call = "& $call"
    }

    return $call
}
