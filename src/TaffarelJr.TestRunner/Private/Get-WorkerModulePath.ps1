using namespace System.Collections.Generic

function Get-WorkerModulePath {
    <#
    .SYNOPSIS
        Returns the path of every module a parallel worker needs to run
        Invoke-TestFileProcess: this module and the modules it requires, as
        loaded here, each listed after the ones it requires.
    .DESCRIPTION
        A worker runspace starts with nothing loaded, and not every module
        can be found by name, so it imports each by the path it was loaded from
        here. Only this module's own chain is listed - whatever else the
        caller has loaded is not the worker's business - and the order is the
        one the imports have to happen in.
    .OUTPUTS
        The paths, one at a time.
    #>
    [CmdletBinding()]
    param()

    $paths = [List[string]]::new()

    function Add-ModulePath {
        param($Module)

        foreach ($required in $Module.RequiredModules) {
            Add-ModulePath -Module $required
        }

        if ($Module.Path -and -not $paths.Contains($Module.Path)) {
            $paths.Add($Module.Path)
        }
    }

    Add-ModulePath -Module $ExecutionContext.SessionState.Module
    return $paths.ToArray()
}
