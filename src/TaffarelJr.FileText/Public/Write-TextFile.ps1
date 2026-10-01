using namespace System.IO
using namespace System.Text

function Write-TextFile {
    <#
    .SYNOPSIS
        Writes text back with the encoding and line ending it already had.
    .DESCRIPTION
        -LikeFilePath supplies both when Path does not exist yet:
        a file only now being created,
        that should still come out looking like a sibling already on disk.
        Falls back to UTF-8 without a BOM and this process's own line ending
        only when neither Path nor LikeFilePath exists -
        there being nothing on disk yet to match.
    .PARAMETER Path
        The file to write.
    .PARAMETER Lines
        Joined with the resolved line ending and given exactly one trailing one.
        Use this, not -Content, for anything built up a line at a time.
    .PARAMETER Content
        Written exactly as given.
        For the rarer case where the caller has already assembled the whole file,
        trailing line ending included.
    .PARAMETER LikeFilePath
        A sibling file to copy the encoding and line ending from,
        when -Path itself does not exist yet.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Lines')]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [AllowEmptyString()]
        [string]$Content,

        [string]$LikeFilePath
    )

    $reference = if (Test-Path -LiteralPath $Path) {
        $Path
    }
    elseif ($LikeFilePath -and (Test-Path -LiteralPath $LikeFilePath)) {
        $LikeFilePath
    }
    else {
        $null
    }

    $encoding = if ($reference) {
        Get-FileEncoding -Path $reference
    }
    else {
        [UTF8Encoding]::new($false)
    }

    $eol = if ($reference) {
        Get-LineEnding -Content ([File]::ReadAllText($reference))
    }
    else {
        [Environment]::NewLine
    }

    $body = if ($PSCmdlet.ParameterSetName -eq 'Lines') {
        ($Lines -join $eol) + $eol
    }
    else {
        $Content
    }

    [File]::WriteAllText($Path, $body, $encoding)
}
