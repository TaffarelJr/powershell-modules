using namespace System.Collections.Generic

function Get-VSCodeCandidate {
    <#
    .SYNOPSIS
        Returns every path one edition of VS Code might be installed at,
        most specific first.
    .DESCRIPTION
        Not exported. The executable derived from the CLI shim on PATH,
        then the shim itself, then the usual install folders. A leftover
        shim from a moved install fails the caller's existence test and
        simply does not become a candidate.
    .PARAMETER Edition
        One entry of the module's edition table: Cli, Exe, and Folder.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Edition
    )

    $candidates = [List[string]]::new()

    # Application only. An alias or a function named 'code' is a perfectly
    # ordinary thing to have, and its .Source is a module name or empty - on
    # which every path operation below fails.
    $cli = @(Get-Command $Edition.Cli -CommandType Application -ErrorAction SilentlyContinue)
    if ($cli.Count -gt 0 -and $cli[0].Source) {
        # <root>\bin\code.cmd -> <root>\Code.exe
        $root = Split-Path -Parent (Split-Path -Parent $cli[0].Source)
        if ($root) {
            $candidates.Add((Join-Path $root $Edition.Exe))
        }

        $candidates.Add($cli[0].Source)
    }

    # Guarded one at a time, because Join-Path rejects an empty path and
    # ProgramFiles(x86) does not exist on every machine.
    $bases = [List[string]]::new()
    if ($env:LOCALAPPDATA) {
        $bases.Add((Join-Path $env:LOCALAPPDATA 'Programs'))
    }

    if ($env:ProgramFiles) {
        $bases.Add($env:ProgramFiles)
    }

    if (${env:ProgramFiles(x86)}) {
        $bases.Add(${env:ProgramFiles(x86)})
    }

    foreach ($base in $bases) {
        $candidates.Add((Join-Path $base $Edition.Folder $Edition.Exe))
    }

    return , $candidates.ToArray()
}
