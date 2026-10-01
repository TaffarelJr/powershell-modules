using namespace System.Text

function Test-BinaryHead {
    <#
    .SYNOPSIS
        Says whether a file's first 8 KB hold a NUL that no UTF-16 or UTF-32
        byte order mark accounts for.
    .DESCRIPTION
        Not exported. The test git uses to tell binary content from text,
        made without reading the rest of the file, so a large binary file
        costs a few kilobytes rather than a full read and decode. UTF-16 and
        UTF-32 text is full of NULs, so a file that starts with one of their
        marks counts as text; without a mark it looks binary, as it does to
        git.
    .PARAMETER Path
        The full path of the file, as Resolve-TextFilePath returns it.
    .OUTPUTS
        [bool]
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $head = Read-FileHead -Path $Path -Count 8KB
    $bom = Get-BomEncoding -Byte $head
    if ($bom.Encoding -is [UnicodeEncoding] -or $bom.Encoding -is [UTF32Encoding]) {
        return $false
    }

    return [Array]::IndexOf($head, [byte]0) -ge 0
}
