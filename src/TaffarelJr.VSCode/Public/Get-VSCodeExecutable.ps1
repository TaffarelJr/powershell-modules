function Get-VSCodeExecutable {
    <#
    .SYNOPSIS
        Returns the path to the VS Code executable, or nothing if none is
        installed.
    .DESCRIPTION
        Looks for the executable beside the bin folder of the CLI shim on
        PATH first, then the shim itself, then the usual Windows install
        folders: under LOCALAPPDATA\Programs, ProgramFiles, ProgramW6432,
        and ProgramFiles(x86). The executable is preferred over the shim
        because launching a .cmd shim flashes a console window, while the
        executable returns immediately. Without -Edition, Stable wins over
        Insiders when both are installed.

        On macOS and Linux only PATH is searched, so the code command has
        to be on it - on macOS through VS Code's "Shell Command: Install
        'code' command in PATH". Other builds of the editor, such as
        VSCodium or code-oss, are not looked for.
    .PARAMETER Edition
        Looks for only this edition. Omit it to take Stable if it is
        installed, otherwise Insiders.
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        System.String. The full path, or nothing when no install is found.
    .EXAMPLE
        Get-VSCodeExecutable

        Returns the path of the VS Code that Start-VSCode would launch.
    .EXAMPLE
        $exe = Get-VSCodeExecutable -Edition Insiders
        if (-not $exe) {
            Write-Warning 'VS Code Insiders is not installed.'
        }

        Checks for one edition before relying on it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.VSCode/README.md
    .LINK
        Start-VSCode
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition
    )

    try {
        $ErrorActionPreference = 'Stop'

        foreach ($known in $script:VSCodeEditions) {
            if ($Edition -and $known.Name -ne $Edition) {
                continue
            }

            $candidates = @(Get-VSCodeCandidate -Edition $known)
            foreach ($candidate in $candidates) {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return $candidate
                }
            }
        }

        return
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
