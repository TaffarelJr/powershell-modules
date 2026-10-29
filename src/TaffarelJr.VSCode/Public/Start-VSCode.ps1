using namespace System.Collections.Generic

function Start-VSCode {
    <#
    .SYNOPSIS
        Opens folders, workspaces, or files in VS Code as a separate process.
    .DESCRIPTION
        Returns as soon as the editor process starts, and never waits for
        it to close; the editor is not handed this session's console
        streams, so a caller whose output is captured does not wait for it
        either. Paths are passed in the order given, in one launch: several
        folders open together in one window, a workspace opens as itself,
        and files open as tabs. Relative paths resolve against the current
        location, which the editor also starts in. Throws when VS Code
        cannot be found or launched, or when a path is blank or not in the
        file system. On Windows, an editor extracted from a downloaded .zip
        carries the mark of the web, which the shell will not start; the
        error names the Unblock-File call that fixes it.

        A path that is refused, or an editor that cannot be found or
        launched, is a terminating error for the call, and in a pipeline it
        stops the pipeline: nothing is launched.

        -WhatIf and -Confirm name every path the one launch would open, once
        VS Code has been found.
        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        What to open: a folder, a .code-workspace file, or a file. Taken
        from the pipeline as strings, or as objects carrying a Path or
        FullName property - a PathInfo, FileInfo, or DirectoryInfo - or
        dictionaries with a Path or FullName entry.
        Everything piped in is opened by one launch.
    .PARAMETER Window
        New opens a new window, Reuse opens in the last active one. Omit
        it to leave the choice to VS Code.
    .PARAMETER Edition
        Launches only this edition. Omit it to take Stable if it is
        installed, otherwise Insiders.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. A path as a string; or an object with a Path or
        FullName property, such as the items Get-ChildItem returns.
    .OUTPUTS
        None. The editor is started in a process of its own.
    .EXAMPLE
        Start-VSCode -Path ./my-repo

        Opens the folder in VS Code.
    .EXAMPLE
        Get-ChildItem -Path ./repos -Directory | Start-VSCode -Window New

        Opens every repository folder together, in one new window.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.VSCode/README.md
    .LINK
        Get-VSCodeExecutable
    .LINK
        New-VSCodeWorkspaceFile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object[]]$Path,

        [ValidateSet('New', 'Reuse')]
        [string]$Window,

        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            $paths = [List[string]]::new()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            foreach ($item in $Path) {
                $paths.Add((ConvertTo-VSCodeLaunchPath -InputObject $item))
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            $lookup = @{}
            $name = 'VS Code'
            if ($Edition) {
                $lookup['Edition'] = $Edition
                $name = "VS Code ($Edition)"
            }

            $executable = Get-VSCodeExecutable @lookup
            if (-not $executable) {
                throw "$name was not found. Install it, or check that its install folder or CLI shim is reachable."
            }

            $windowOption = @{}
            if ($Window) {
                $windowOption['Window'] = $Window
            }

            $arguments = @(Get-VSCodeArgument -Path $paths.ToArray() @windowOption)
            $target = $paths -join ', '
            if (-not $PSCmdlet.ShouldProcess($target, "Open in $name")) {
                return
            }

            try {
                Start-VSCodeProcess -Executable $executable -Argument $arguments
            }
            catch {
                throw "Could not launch VS Code: $($_.Exception.Message)"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
