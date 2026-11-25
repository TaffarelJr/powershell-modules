using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation

function Rename-NameToken {
    <#
    .SYNOPSIS
        Replaces a token in file and folder names.
    .DESCRIPTION
        Not exported. The longest path goes first. A child's path is always
        longer than its parent's, so every item is reached before its own
        ancestors, whose renaming would stale its path, without assuming a
        separator character. A rename that fails, usually because the new
        name is taken, is recorded with both paths, since naming both is what
        lets the gap be cleared, and the pass moves on to the next item.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them. Only those whose
        name holds the token are renamed.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet, whose ShouldProcess is asked with each
        item's full path and its new name before it is renamed. An item it
        declines is neither renamed nor counted.
    .OUTPUTS
        A PSCustomObject with Renamed, how many items were renamed, and
        Failed, one "<from> -> <to> - <reason>" line for each item that could
        not be.
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Asks the public caller''s ShouldProcess, passed in as -Cmdlet.')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To,

        [Parameter(Mandatory)]
        [PSCmdlet]$Cmdlet
    )

    $named = @($Item | Where-Object { $_.Name.Contains($From) })
    $ordered = @($named | Sort-Object { $_.FullName.Length } -Descending)
    $renamed = 0
    $failed = [List[string]]::new()
    foreach ($entry in $ordered) {
        $newName = $entry.Name.Replace($From, $To)
        if (-not $Cmdlet.ShouldProcess($entry.FullName, "Rename to '$newName'")) {
            continue
        }

        Write-Verbose "Renaming '$($entry.FullName)' to '$newName'."
        try {
            Rename-Item `
                -LiteralPath $entry.FullName `
                -NewName $newName `
                -WhatIf:$false `
                -Confirm:$false `
                -Verbose:$false `
                -ErrorAction Stop
            $renamed++
        }
        catch {
            $reason = $_.Exception.GetBaseException().Message
            $failed.Add("$($entry.FullName) -> $newName - $reason")
        }
    }

    return [PSCustomObject]@{
        Renamed = $renamed
        Failed  = $failed.ToArray()
    }
}
