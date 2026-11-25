using namespace System.IO

function Resolve-WriteReference {
    <#
    .SYNOPSIS
        Returns the existing file a write takes its encoding and line ending
        from, or nothing when there is none.
    .DESCRIPTION
        Not exported. The file being written, when it already holds something,
        and otherwise the sibling named by -LikeFilePath, when that does.
        An empty file has nothing to preserve, so it is passed over, and so is
        a sibling that is not there. A sibling that is a folder or a blank
        path is a mistake, and throws.
    .PARAMETER Path
        The full path of the file being written.
    .PARAMETER LikeFilePath
        The sibling to fall back on, as the caller gave it.
    .OUTPUTS
        The full path of the file to read, or nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$LikeFilePath
    )

    $candidates = @($Path)
    if ($PSBoundParameters.ContainsKey('LikeFilePath')) {
        $candidates += Resolve-TextFilePath -Path $LikeFilePath
    }

    foreach ($candidate in $candidates) {
        $isFile = Test-Path -LiteralPath $candidate -PathType Leaf
        if ($isFile -and ([FileInfo]$candidate).Length -gt 0) {
            return $candidate
        }
    }
}
