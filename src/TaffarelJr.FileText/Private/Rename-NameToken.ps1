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
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them. Only those whose
        name holds the token are renamed.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet, whose ShouldProcess is asked with each
        item's full path and its new name before it is renamed; an item it
        declines is neither renamed nor counted.
    .OUTPUTS
        A PSCustomObject with Renamed (how many items were renamed)
        and Failed (one "<from> -> <to> - <reason>" line
        per item that could not be).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Asks the public caller''s ShouldProcess, passed in as -Cmdlet.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
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
        if (-not $Cmdlet.ShouldProcess($item.FullName, "Rename to '$newName'")) {
            continue
        }

        Write-Verbose "Renaming '$($item.FullName)' to '$newName'."
        try {
            Rename-Item `
                -LiteralPath $item.FullName `
                -NewName $newName `
                -WhatIf:$false `
                -Confirm:$false `
                -ErrorAction Stop
            $renamed++
        }
        catch {
            $failed.Add("$($item.FullName) -> $newName - $($_.Exception.GetBaseException().Message)")
        }
    }

    return [PSCustomObject]@{
        Renamed = $renamed
        Failed  = @($failed)
    }
}
