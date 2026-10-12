function Get-VSCodeExecutable {
    <#
    .SYNOPSIS
        Returns the path to the VS Code executable, or $null if none is
        installed.
    .DESCRIPTION
        Looks for the executable beside the CLI shim on PATH first, then
        the shim itself, then the usual install folders. The executable
        is preferred over the shim because launching a .cmd shim flashes
        a console window, while the executable returns immediately.
        Without -Edition, Stable wins over Insiders when both are
        installed.
    .PARAMETER Edition
        Looks for only this edition. Omit it to take Stable if it is
        installed, otherwise Insiders.
    .OUTPUTS
        The full path, or $null when nothing is found.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition
    )

    foreach ($known in $script:VSCodeEditions) {
        if ($Edition -and $known.Name -ne $Edition) {
            continue
        }

        $candidates = Get-VSCodeCandidate -Edition $known
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    return $null
}
