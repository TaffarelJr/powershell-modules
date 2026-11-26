using namespace System.Collections.Generic
using namespace System.Management.Automation

function Edit-ContentToken {
    <#
    .SYNOPSIS
        Replaces a token in the content of every eligible file.
    .DESCRIPTION
        Not exported. A file that cannot be read or written is recorded and
        stepped over, so the caller can name every gap at once. A folder, a
        symbolic link, and a junction are stepped over without being read: a
        link stands for a file that is either elsewhere in the tree and
        handled on its own, or outside it and none of this pass's business. A
        hard link is an ordinary file with a second name, and is edited like
        any other. A file whose approval prompt cannot be answered stops the
        pass instead, since no other file can be answered either.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER SkipExtension
        Extensions, each with its dot, of files not worth reading.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet, handed to Edit-TextFileToken for each
        file. A file its ShouldProcess declines is neither edited nor counted.
    .OUTPUTS
        A PSCustomObject with Edited, how many files were rewritten; Warning,
        one line for each file skipped as binary; and Failed, one
        "<path> - <reason>" line for each file that could not be updated.
    #>
    [CmdletBinding()]
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
        [AllowEmptyCollection()]
        [string[]]$SkipExtension,

        [Parameter(Mandatory)]
        [PSCmdlet]$Cmdlet
    )

    $edited = 0
    $warnings = [List[string]]::new()
    $failed = [List[string]]::new()
    $files = @($Item | Where-Object {
            -not $_.PSIsContainer -and
            $_.LinkType -notin 'Junction', 'SymbolicLink' -and
            $_.Extension -notin $SkipExtension
        })
    foreach ($file in $files) {
        try {
            $status = Edit-TextFileToken -Path $file.FullName -From $From `
                -To $To -Cmdlet $Cmdlet
        }
        catch {
            if ($_.FullyQualifiedErrorId -eq 'TextFileApprovalFailed') {
                throw
            }

            $reason = $_.Exception.GetBaseException().Message
            $failed.Add("$($file.FullName) - $reason")
            continue
        }

        if ($status -eq 'Edited') {
            $edited++
        }
        elseif ($status -eq 'Binary') {
            $warnings.Add("Skipped binary content: $($file.FullName)")
        }
    }

    return [PSCustomObject]@{
        Edited  = $edited
        Warning = $warnings.ToArray()
        Failed  = $failed.ToArray()
    }
}
