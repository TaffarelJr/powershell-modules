using namespace System.Collections.Generic
using namespace System.Diagnostics

function Stop-NativeProcessTree {
    <#
    .SYNOPSIS
        Kills a process along with the processes it started, including any
        that have outlived it.
    .DESCRIPTION
        Not exported. The second attempt, for output pipes still held open
        after Process.Kill($true): it reads the whole process table, which
        is slow, and kills every process descended from the root by parent
        id. On Windows a process keeps its parent's id after the parent
        exits, so one whose parent has already exited is found too; one
        created before its supposed parent belongs to an earlier owner of a
        reused id and is left alone.
    .PARAMETER Process
        The process at the root of the tree. It may already have exited, but
        must not have been disposed.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Only ends a process tree the module itself started and whose timeout has passed.')]
    param(
        [Parameter(Mandatory)]
        [Process]$Process
    )

    $descendants = [List[int]]::new()
    if ($IsWindows) {
        $snapshot = Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId, CreationDate
        $parents = [Queue[object]]::new()
        $parents.Enqueue(@($Process.Id, $Process.StartTime))
        while ($parents.Count -gt 0) {
            $parentId, $parentStart = $parents.Dequeue()
            foreach ($candidate in $snapshot) {
                $isChild = $candidate.ParentProcessId -eq $parentId -and $candidate.ProcessId -ne $parentId
                if ($isChild -and $candidate.CreationDate -ge $parentStart) {
                    $descendants.Add($candidate.ProcessId)
                    $parents.Enqueue(@($candidate.ProcessId, $candidate.CreationDate))
                }
            }
        }
    }

    $Process.Kill($true)
    foreach ($id in $descendants) {
        Stop-Process -Id $id -Force -ErrorAction Ignore
    }
}
