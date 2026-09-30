function Get-LoadedPesterPath {
    <#
    .SYNOPSIS
        Returns the path of the newest Pester 5.3.0 or later loaded in this
        session - its manifest when it has one - or nothing when none is.
    .DESCRIPTION
        A Pester imported by its path is not on PSModulePath, so a new process
        importing Pester by name would not find it, or would find another
        version. Handing a child this path lets it import the very Pester
        this session uses.
    .OUTPUTS
        The path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $loaded = @(Get-Module -Name 'Pester' | Where-Object { $_.Version -ge [version]'5.3.0' })
    if (-not $loaded) {
        return
    }

    $newest = $loaded | Sort-Object -Property Version -Descending | Select-Object -First 1
    $manifest = Join-Path $newest.ModuleBase 'Pester.psd1'
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        return $manifest
    }

    return $newest.Path
}
