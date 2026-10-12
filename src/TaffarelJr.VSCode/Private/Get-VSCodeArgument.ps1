using namespace System.Collections.Generic

function Get-VSCodeArgument {
    <#
    .SYNOPSIS
        Builds the argument list for launching VS Code.
    .DESCRIPTION
        Not exported. Split out from Start-VSCode so the argument shape is
        unit-testable without launching a process.
    .PARAMETER Path
        The paths to open, in order.
    .PARAMETER Window
        New adds --new-window, Reuse adds --reuse-window. Omit it to leave
        the choice to VS Code.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [ValidateSet('New', 'Reuse')]
        [string]$Window
    )

    $arguments = [List[string]]::new()
    if ($Window -eq 'New') {
        $arguments.Add('--new-window')
    }
    elseif ($Window -eq 'Reuse') {
        $arguments.Add('--reuse-window')
    }

    $arguments.AddRange($Path)
    return , $arguments.ToArray()
}
