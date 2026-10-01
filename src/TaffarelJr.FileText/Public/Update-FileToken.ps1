function Update-FileToken {
    <#
    .SYNOPSIS
        Replaces a token in one file's content,
        keeping its encoding and line ending.
    .DESCRIPTION
        Declines any file whose decoded text contains a NUL,
        which is the reliable mark of binary content:
        an extension deny-list cannot list every binary format,
        and rewriting one as text destroys it.
    .PARAMETER Path
        The file to update.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .OUTPUTS
        [bool] - whether the file was rewritten.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$From,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$To
    )

    $file = Read-TextFile -Path $Path
    if (-not $file.Content.Contains($From)) {
        return $false
    }

    if ($file.Content.Contains([char]0)) {
        return $false
    }

    Write-TextFile -Path $Path -Content $file.Content.Replace($From, $To)
    return $true
}
