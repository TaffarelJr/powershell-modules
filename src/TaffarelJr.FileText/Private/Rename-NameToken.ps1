using namespace System.Collections.Generic

function Rename-NameToken {
    <#
    .SYNOPSIS
        Replaces a token in file and directory names.
    .DESCRIPTION
        Not exported. A rename that fails -
        usually because the target already exists -
        is recorded with both paths,
        since only naming both lets the gap be cleared,
        and the pass moves on to the next item.
    .OUTPUTS
        A PSCustomObject with Renamed (how many items were renamed)
        and Failed (one "<from> -> <to> - <reason>" line
        per item that could not be).
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To
    )

    # Longest path first. A child's path is always longer than its parent's,
    # so this reaches every item before its own ancestors
    # without assuming a separator character.
    $named = @($Item |
        Where-Object { $_.Name.Contains($From) } |
        Sort-Object { $_.FullName.Length } -Descending)

    $renamed = 0
    $failed = [List[string]]::new()
    foreach ($item in $named) {
        $newName = $item.Name.Replace($From, $To)
        try {
            Rename-Item -LiteralPath $item.FullName -NewName $newName
            $renamed++
        }
        catch {
            $failed.Add("$($item.FullName) -> $newName - $($_.Exception.Message)")
        }
    }

    return [PSCustomObject]@{
        Renamed = $renamed
        Failed  = @($failed)
    }
}
