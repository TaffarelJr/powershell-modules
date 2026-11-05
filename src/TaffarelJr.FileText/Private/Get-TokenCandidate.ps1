using namespace System.Collections.Generic

function Get-TokenCandidate {
    <#
    .SYNOPSIS
        Returns every item under a tree that a token pass is allowed to touch.
    .DESCRIPTION
        Not exported. A folder named in -Exclude is neither listed nor entered,
        wherever it sits in the tree, so its contents cost nothing and cannot
        raise a warning. A folder link is listed - its own name can be renamed -
        but not entered, so the walk never leaves the tree or goes round a
        loop. A folder that could not be listed is recorded rather than
        silently dropped, so a partial pass cannot pass for a complete one.
    .PARAMETER Path
        The folder to search.
    .PARAMETER Exclude
        Folder or file names to skip, compared whole and without regard to case.
    .OUTPUTS
        A PSCustomObject with Item (the candidate items)
        and Warning (one line per folder that could not be listed).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Exclude
    )

    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $items = [List[object]]::new()
    $warnings = [List[string]]::new()
    $pending = [Stack[string]]::new()
    $pending.Push($root)

    while ($pending.Count -gt 0) {
        $folder = $pending.Pop()
        try {
            $entries = @(Get-DirectoryEntry -Path $folder)
        }
        catch {
            $warnings.Add("Not searched: $folder - $($_.Exception.GetBaseException().Message)")
            continue
        }

        foreach ($entry in $entries) {
            if ($entry.Name -in $Exclude) {
                continue
            }

            $items.Add($entry)
            if ($entry.PSIsContainer -and -not $entry.LinkType) {
                $pending.Push($entry.FullName)
            }
        }
    }

    return [PSCustomObject]@{
        Item    = $items.ToArray()
        Warning = $warnings.ToArray()
    }
}
