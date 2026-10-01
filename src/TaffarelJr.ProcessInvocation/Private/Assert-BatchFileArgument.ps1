using namespace System.IO
using namespace System.Management.Automation

function Assert-BatchFileArgument {
    <#
    .SYNOPSIS
        Throws when a Windows batch file would be given an argument that
        cmd.exe could act on.
    .DESCRIPTION
        Not exported. cmd.exe parses a batch file's command line again, by
        rules no argument quoting can satisfy: a double quote can end its
        quoting, '&' and '|' run what follows as a command of its own, '<'
        and '>' redirect, '^' escapes, and '%' expands a variable. So an
        argument holding any of " & | < > ^ % is refused on both routes -
        even a single %, because the arguments are joined into one command
        line, where a % in one can pair with a % in the next.
        Arguments without them are left alone, and so is every command that
        is not a batch file.
    .PARAMETER Command
        The command that will really run, as Invoke-NativeCapture resolved
        it for the route it takes - an alias already followed to its target.
        $null when nothing was found, which is never a batch file.
    .PARAMETER Arguments
        The arguments it is about to get.
    #>
    param(
        [AllowNull()]
        [CommandInfo]$Command,

        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Arguments = @()
    )

    $index = -1
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -match '["&|<>^%]') {
            $index = $i
            break
        }
    }

    if (-not $IsWindows -or $index -lt 0) {
        return
    }

    $isApplication = $Command -is [ApplicationInfo]
    if ($isApplication -and [Path]::GetExtension($Command.Source) -in '.cmd', '.bat') {
        $shown = Hide-UrlCredential -Text $Command.Source
        throw "Argument $($index + 1) for the batch file '$shown' holds one of "" & | < > ^ %." +
        ' cmd.exe parses a batch file''s arguments again, where those characters would run commands,' +
        ' redirect, or expand variables.' +
        ' Call the program''s real .exe instead, or pass the value through -StdIn, -Environment, or a file.'
    }
}
