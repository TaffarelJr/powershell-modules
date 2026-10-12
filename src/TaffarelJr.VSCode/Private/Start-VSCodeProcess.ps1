using namespace System.Diagnostics

function Start-VSCodeProcess {
    <#
    .SYNOPSIS
        Starts an executable as a separate process and returns without
        waiting for it.
    .DESCRIPTION
        Not exported. Arguments go through ProcessStartInfo.ArgumentList
        rather than Start-Process -ArgumentList, which joins an array with
        spaces and never quotes - a path containing a space, as in
        'OneDrive - Company', would otherwise arrive as several arguments.
        The one place in the module that actually launches anything, which
        is also what lets a test replace it.
    .PARAMETER Executable
        The program to start.
    .PARAMETER Argument
        Its arguments, one element per argument.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Executable,

        [Parameter(Mandatory)]
        [string[]]$Argument
    )

    $info = [ProcessStartInfo]::new($Executable)
    foreach ($item in $Argument) {
        $info.ArgumentList.Add($item)
    }

    $info.UseShellExecute = $false
    $process = [Process]::Start($info)
    $process.Dispose()
}
