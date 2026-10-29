using namespace System.IO

function Read-FileHead {
    <#
    .SYNOPSIS
        Returns the first bytes of a file, without reading the rest of it.
    .DESCRIPTION
        Not exported. A file shorter than -Count comes back whole. One read
        can return fewer bytes than asked for even when more are coming - on
        a network share, say - so reading goes on until -Count bytes or the
        end of the file.
    .PARAMETER Path
        The full path of the file, as Resolve-TextFilePath returns it.
    .PARAMETER Count
        How many bytes to read at most.
    .OUTPUTS
        The bytes, as one byte array.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Count
    )

    $buffer = [byte[]]::new($Count)
    try {
        $stream = [File]::OpenRead($Path)
    }
    catch {
        throw "Cannot read '$Path': $($_.Exception.GetBaseException().Message)"
    }

    try {
        $read = $stream.ReadAtLeast($buffer, $Count, $false)
    }
    finally {
        $stream.Dispose()
    }

    $head = [byte[]]::new($read)
    [Array]::Copy($buffer, $head, $read)
    # One value that is an array: unrolled, an empty file would come back as
    # nothing at all rather than as no bytes.
    return , $head
}
