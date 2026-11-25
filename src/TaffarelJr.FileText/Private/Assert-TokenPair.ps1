using namespace System.IO

function Assert-TokenPair {
    <#
    .SYNOPSIS
        Refuses a replacement that cannot be a file name, or that a re-run
        would apply again.
    .DESCRIPTION
        Not exported. A replacement holding a character no file name can hold
        is refused, because every name it made would be unusable. One that
        contains the token is refused unless -Force says to go ahead: the
        next run would find the token inside every name the last one wrote
        and rename those too.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER Force
        Allows a replacement that contains the token.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To,

        [switch]$Force
    )

    if ($To.IndexOfAny([Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "Cannot rename '$From' to '$To': not a legal file name."
    }

    if ($To.Contains($From) -and -not $Force) {
        $reason = 'the new name contains the old one,' +
        ' so a re-run would rename it again.'
        throw "Cannot rename '$From' to '$To': $reason" +
        ' Pass -Force to go ahead anyway.'
    }
}
