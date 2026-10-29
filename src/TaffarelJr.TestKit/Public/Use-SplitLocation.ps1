function Use-SplitLocation {
    <#
    .SYNOPSIS
        Runs a script block with PowerShell's location in one folder and the
        process's working directory in another, then puts both back.
    .DESCRIPTION
        Set-Location moves only PowerShell's location. .NET resolves a relative
        path against the process's working directory, and a program started
        through System.Diagnostics.Process starts in it, so code that hands a
        relative path or a default directory to .NET reads and writes the wrong
        folder while PowerShell's own commands look in the right one. A test
        that never separates the two cannot see that mistake.

        The block runs in the caller's own scope, so a variable it assigns
        is the caller's variable. Both locations are restored even when the
        script block throws; what it throws is then raised by this command, as
        a terminating error that carries the block's own exception.
    .PARAMETER Location
        The folder PowerShell is in while the block runs.
    .PARAMETER ProcessDirectory
        The file-system folder the process is in while the block runs.
    .PARAMETER ScriptBlock
        The code to run.
    .INPUTS
        None.
    .OUTPUTS
        System.Object. Whatever the script block writes, one item at a time.
    .EXAMPLE
        $read = Use-SplitLocation -Location $here -ProcessDirectory $there `
            -ScriptBlock { Read-TextFile -Path .\f.txt }

        Reads .\f.txt with PowerShell in $here and the process in $there; a
        function that resolved the path the .NET way would read $there's
        file instead.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container },
            ErrorMessage = "no such folder '{0}'")]
        [string]$Location,

        [Parameter(Mandatory)]
        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                    throw "no such folder '$_'"
                }

                if ((Get-Item -LiteralPath $_).PSProvider.Name -ne 'FileSystem') {
                    throw "not a file-system folder: '$_'; a process can only be in a folder on disk"
                }

                return $true
            })]
        [string]$ProcessDirectory,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $ErrorActionPreference = 'Stop'

        $original = [Environment]::CurrentDirectory
        $processFolder = Convert-Path -LiteralPath $ProcessDirectory
        Push-Location -LiteralPath $Location
        try {
            [Environment]::CurrentDirectory = $processFolder
            # Dot-sourced: a call with & gets a scope of its own, and the block's
            # assignments would be lost when it ends.
            . $ScriptBlock
        }
        finally {
            [Environment]::CurrentDirectory = $original
            Pop-Location
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
