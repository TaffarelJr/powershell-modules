function New-ReleaseTestFolder {
    <#
    .SYNOPSIS
        Creates a new temporary folder holding the named files, and
        returns its full path.
    .DESCRIPTION
        Not exported - a test-only fixture, shared by this module's tests.
        Each file is created with a little text, along with any folder its
        relative path names. The caller removes the folder in a finally
        block.
    .PARAMETER File
        Paths of the files to create, relative to the new folder.
    .OUTPUTS
        The folder's full path.
    #>
    [CmdletBinding()]
    param(
        [string[]]$File = @()
    )

    $folder = Join-Path ([System.IO.Path]::GetTempPath()) "releases-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $folder | Out-Null
    foreach ($relative in $File) {
        $path = Join-Path $folder $relative
        $parent = Split-Path -Parent $path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Set-Content -LiteralPath $path -Value 'x'
    }

    return $folder
}
