using namespace System.Diagnostics

function New-VSCodeStartInfo {
    <#
    .SYNOPSIS
        Builds the ProcessStartInfo that launches the editor, without
        starting anything.
    .DESCRIPTION
        Not exported. Arguments go through ProcessStartInfo.ArgumentList
        rather than Start-Process -ArgumentList, which joins an array with
        spaces and never quotes - a path containing a space, as in
        'OneDrive - Company', would otherwise arrive as several arguments.

        The editor must not hold on to this session's standard streams: a
        caller whose output is being captured would otherwise wait until
        the editor closed. On Windows it is started through the shell,
        which hands it none of this process's handles. Elsewhere sh starts
        it under nohup, in the background, with its streams pointed at
        /dev/null, so neither a captured read nor closing the terminal
        waits on or ends it; the executable and its arguments follow the
        script as separate items, never spliced into its text.

        The process starts in PowerShell's current location, not the host
        process's own directory, which Set-Location does not change - the
        editor's own default folder and terminals follow it. A location
        outside the file system leaves the working directory unset.
    .PARAMETER Executable
        The program to start.
    .PARAMETER Argument
        Its arguments, one element per argument.
    .PARAMETER OnWindows
        Builds the Windows form when true, the sh form when false; this
        platform's own when omitted.
    .OUTPUTS
        The ProcessStartInfo.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Builds a ProcessStartInfo in memory; Start-VSCode asks ShouldProcess before the launch.')]
    [OutputType([System.Diagnostics.ProcessStartInfo])]
    param(
        [Parameter(Mandatory)]
        [string]$Executable,

        [Parameter(Mandatory)]
        [string[]]$Argument,

        [bool]$OnWindows = $IsWindows
    )

    if ($OnWindows) {
        $info = [ProcessStartInfo]::new($Executable)
    }
    else {
        $info = [ProcessStartInfo]::new('/bin/sh')
        $info.ArgumentList.Add('-c')
        $info.ArgumentList.Add('nohup "$0" "$@" </dev/null >/dev/null 2>&1 &')
        $info.ArgumentList.Add($Executable)
    }

    foreach ($item in $Argument) {
        $info.ArgumentList.Add($item)
    }

    $location = Get-Location
    if ($location.Provider.Name -eq 'FileSystem') {
        $info.WorkingDirectory = $location.ProviderPath
    }

    $info.UseShellExecute = $OnWindows
    return $info
}
