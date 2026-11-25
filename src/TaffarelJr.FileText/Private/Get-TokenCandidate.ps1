using namespace System.Collections.Generic

function Get-TokenCandidate {
    <#
    .SYNOPSIS
        Returns every item under a folder that a token pass is allowed to
        touch.
    .DESCRIPTION
        Not exported. A folder named in -Exclude is neither listed nor
        entered, wherever it sits in the tree, so what is in it costs nothing
        and cannot raise a warning. A link to a folder is listed, because its
        own name can be renamed, but not entered, so the walk never leaves
        the tree or goes round a loop. A folder that cannot be listed is
        recorded rather than dropped, so a partial pass cannot pass for a
        complete one. Hidden items are included.
    .PARAMETER Path
        The full path of the folder to search.
    .PARAMETER Exclude
        File and folder names to skip, each compared with the whole of an
        item's name, without regard to case and without wildcards.
    .OUTPUTS
        A PSCustomObject with Item, the candidates, and Warning, one line for
        each folder that could not be listed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Exclude
    )

    $items = [List[object]]::new()
    $warnings = [List[string]]::new()
    $pending = [Stack[string]]::new()
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        $folder = $pending.Pop()
        try {
            $entries = @(Get-ChildItem -LiteralPath $folder -Force)
        }
        catch {
            $reason = $_.Exception.GetBaseException().Message
            $warnings.Add("Not searched: $folder - $reason")
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
