using namespace System.Collections.Generic

function Start-VSCode {
    <#
    .SYNOPSIS
        Opens folders, workspaces, or files in VS Code as a separate,
        detached process.
    .DESCRIPTION
        Returns as soon as the editor process starts, and never waits for
        it to close. Paths are passed in the order given: VS Code opens
        the first folder or workspace and treats files as tabs, so a
        workspace followed by a file opens that workspace with the file
        focused. Relative paths resolve against the current location.
        Throws when VS Code cannot be found or launched.
    .PARAMETER Path
        What to open: a folder, a .code-workspace file, or a file. Taken
        from the pipeline by value, or by a FullName property as a
        FileInfo or DirectoryInfo carries. Everything piped in is opened
        by one launch.
    .PARAMETER Window
        New opens a new window, Reuse opens in the last active one. Omit
        it to leave the choice to VS Code.
    .PARAMETER Edition
        Launches only this edition. Omit it to take Stable if it is
        installed, otherwise Insiders.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [ValidateSet('New', 'Reuse')]
        [string]$Window,

        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition
    )

    begin {
        $paths = [List[string]]::new()
    }

    process {
        foreach ($item in $Path) {
            $paths.Add($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($item))
        }
    }

    end {
        $lookup = @{}
        if ($Edition) {
            $lookup['Edition'] = $Edition
        }

        $executable = Get-VSCodeExecutable @lookup
        if (-not $executable) {
            throw 'VS Code was not found. Install it, or check that its install folder or CLI shim is reachable.'
        }

        $windowOption = @{}
        if ($Window) {
            $windowOption['Window'] = $Window
        }

        $arguments = Get-VSCodeArgument -Path $paths.ToArray() @windowOption
        try {
            Start-VSCodeProcess -Executable $executable -Argument $arguments
        }
        catch {
            throw "Could not launch VS Code ($($_.Exception.Message))."
        }
    }
}
