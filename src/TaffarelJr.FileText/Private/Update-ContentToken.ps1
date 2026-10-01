using namespace System.Collections.Generic

function Update-ContentToken {
    <#
    .SYNOPSIS
        Replaces a token in the content of every eligible file.
    .DESCRIPTION
        Not exported.
        A file that cannot be read or written is recorded and stepped over,
        so the caller can name every gap at once - see Rename-Token.
        A symbolic link or junction is stepped over without being read: it
        stands for a file that is either elsewhere in the tree and handled on
        its own, or outside it and none of this pass's business. A hard link
        is not one of those - it is an ordinary file that has another name as
        well - so it is edited like any other. A link whose target holds the
        token is warned about, since nothing here rewrites a target, and a
        rename of what it points at would leave it dangling.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER SkipExtension
        Extensions, with their dot, of files not worth reading.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet, handed to Edit-TextFileToken for each
        file; a file its ShouldProcess declines is neither edited nor counted.
        When it cannot ask - no one can answer a -Confirm prompt - that error
        stops the pass, rather than being recorded against every file.
    .OUTPUTS
        A PSCustomObject with Edited (how many files were rewritten),
        Warning (one line per file skipped as binary,
        and per link whose target holds the token),
        and Failed (one "<path> - <reason>" line
        per file that could not be updated).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Each file is confirmed by the public caller''s ShouldProcess, passed in as -Cmdlet.')]
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
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $edited = 0
    $warnings = [List[string]]::new()
    $failed = [List[string]]::new()
    $links = @($Item | Where-Object { $_.LinkType -in 'SymbolicLink', 'Junction' })
    foreach ($link in $links) {
        if ($link.LinkTarget -and $link.LinkTarget.Contains($From)) {
            $warnings.Add("Link target still says '$From': $($link.FullName) -> $($link.LinkTarget)")
        }
    }

    $files = @($Item | Where-Object {
            -not $_.PSIsContainer -and
            $_.LinkType -notin 'SymbolicLink', 'Junction' -and
            $_.Extension -notin $SkipExtension
        })

    foreach ($file in $files) {
        try {
            switch (Edit-TextFileToken -Path $file.FullName -From $From -To $To -Cmdlet $Cmdlet) {
                'Edited' {
                    $edited++
                }
                'Binary' {
                    $warnings.Add("Skipped binary content: $($file.FullName)")
                }
            }
        }
        catch {
            if ($_.FullyQualifiedErrorId -eq 'TextFileApprovalFailed') {
                throw
            }

            $failed.Add("$($file.FullName) - $($_.Exception.GetBaseException().Message)")
        }
    }

    return [PSCustomObject]@{
        Edited  = $edited
        Warning = $warnings.ToArray()
        Failed  = $failed.ToArray()
    }
}
