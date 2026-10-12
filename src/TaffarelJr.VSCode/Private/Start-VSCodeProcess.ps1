using namespace System.Diagnostics
using namespace System.IO

function Start-VSCodeProcess {
    <#
    .SYNOPSIS
        Starts an executable as a separate process and returns without
        waiting for it.
    .DESCRIPTION
        Not exported. The one place in the module that actually launches
        anything, which is also what lets a test replace it. What is started,
        where, and how is New-VSCodeStartInfo's to decide.

        A .cmd or .bat file - VS Code's CLI shim, when no Code.exe sits
        beside its bin folder - is run by cmd.exe, which reads
        & | < > ^ % " and ! in its arguments as commands, redirections, and
        variables. Such an argument is refused rather than passed on.

        The executable has to exist, and on macOS and Linux carry an execute
        bit, before anything starts: there the editor is started in the
        background, so a failure after the start is never seen. On Windows,
        a file that carries the mark of the web - every file extracted from
        a downloaded .zip - is refused by the shell, and the error says to
        unblock it.
    .PARAMETER Executable
        The program to start.
    .PARAMETER Argument
        Its arguments, one element per argument.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Start-VSCode, its public caller, asks ShouldProcess before calling it.')]
    param(
        [Parameter(Mandatory)]
        [string]$Executable,

        [Parameter(Mandatory)]
        [string[]]$Argument
    )

    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "The executable does not exist: $Executable"
    }

    if (-not $IsWindows) {
        $executeBits = [UnixFileMode]'UserExecute, GroupExecute, OtherExecute'
        if (([File]::GetUnixFileMode($Executable) -band $executeBits) -eq 0) {
            throw "The executable has no execute bit: $Executable. Run chmod +x on it, or reinstall VS Code."
        }
    }

    $extension = [Path]::GetExtension($Executable)
    if ($extension -in '.cmd', '.bat') {
        foreach ($item in $Argument) {
            if ($item.IndexOfAny([char[]]'&|<>^%"!') -ge 0) {
                throw ("cmd.exe would misread '$item' when running '$Executable', which is a batch file. " +
                    'Repair or reinstall VS Code so that Code.exe sits beside its bin folder, ' +
                    'or open a path without & | < > ^ % " or !.')
            }
        }
    }

    $info = New-VSCodeStartInfo -Executable $Executable -Argument $Argument

    # Set inside VS Code's own extension host, where it makes Code.exe run as
    # plain Node. A shell-executed start cannot be given its own environment,
    # so it is lifted from this process for the moment of the launch.
    $electronMode = $env:ELECTRON_RUN_AS_NODE
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')
    try {
        $process = [Process]::Start($info)
    }
    catch [ComponentModel.Win32Exception] {
        # ERROR_CANCELLED: .NET asks the shell for no UI, so the security
        # prompt for a downloaded file cannot be shown and the start is
        # cancelled instead.
        if ($_.Exception.NativeErrorCode -ne 1223) {
            throw
        }

        # PowerShell reads the typographic quotes as single quotes too.
        $quotedFolder = (Split-Path -Parent $Executable) -replace "['\u2018\u2019\u201A\u201B]", '$0$0'
        throw ("Windows will not start '$Executable': it carries the mark of the web, " +
            'as every file extracted from a downloaded .zip does. ' +
            "Unblock the install folder - Get-ChildItem -LiteralPath '$quotedFolder' -Recurse | " +
            'Unblock-File - then try again.')
    }
    finally {
        [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $electronMode, 'Process')
    }

    if ($null -ne $process) {
        $process.Dispose()
    }
}
