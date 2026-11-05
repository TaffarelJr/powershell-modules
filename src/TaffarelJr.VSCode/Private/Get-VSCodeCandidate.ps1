using namespace System.Collections.Generic

function Get-VSCodeCandidate {
    <#
    .SYNOPSIS
        Returns every path one edition of VS Code might be installed at,
        most specific first.
    .DESCRIPTION
        Not exported. The executable derived from the CLI shim on PATH,
        then the shim itself, then the Windows install folders. A leftover
        shim from a moved install fails the caller's existence test and
        simply does not become a candidate. On Windows only a shim whose
        extension is in PATHEXT counts, both as a candidate and as where
        the executable is worked out from: VS Code's bin folder also holds
        an extensionless script for Unix shells, which Windows cannot
        start.
    .PARAMETER Edition
        One entry of the module's edition table: Cli, Exe, and Folder.
    .OUTPUTS
        The paths, one at a time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Edition
    )

    $candidates = [List[string]]::new()

    # Application only. An alias or a function named 'code' is a perfectly
    # ordinary thing to have, and its .Source is a module name or empty - on
    # which every path operation below fails.
    $shims = @(Get-Command $Edition.Cli -CommandType Application -ErrorAction SilentlyContinue)
    if ($IsWindows) {
        # An empty entry, as a trailing ';' leaves, would match the
        # extensionless script.
        $launchable = @($env:PATHEXT -split ';' | Where-Object { $_ })
        $shims = @($shims.Where({ $launchable -contains $_.Extension }))
    }

    if ($shims.Count -gt 0 -and $shims[0].Source) {
        # <root>\bin\code.cmd -> <root>\Code.exe
        $root = Split-Path -Parent (Split-Path -Parent $shims[0].Source)
        if ($root) {
            $candidates.Add((Join-Path $root $Edition.Exe))
        }

        $candidates.Add($shims[0].Source)
    }

    # ProgramW6432 is the 64-bit folder as a 32-bit PowerShell sees it, and
    # the same as ProgramFiles to a 64-bit one, so a folder named twice is
    # kept once. Join-Path rejects an empty path, hence the guard.
    $roots = @(
        if ($env:LOCALAPPDATA) {
            Join-Path $env:LOCALAPPDATA 'Programs'
        }

        $env:ProgramFiles
        $env:ProgramW6432
        ${env:ProgramFiles(x86)}
    )

    $bases = [List[string]]::new()
    foreach ($base in $roots) {
        if ($base -and $bases -notcontains $base) {
            $bases.Add($base)
        }
    }

    foreach ($base in $bases) {
        $candidates.Add((Join-Path -Path $base -ChildPath $Edition.Folder -AdditionalChildPath $Edition.Exe))
    }

    return $candidates.ToArray()
}
