using namespace System.Collections.Generic
using namespace System.IO

function Update-ContentToken {
    <#
    .SYNOPSIS
        Replaces a token in the content of every eligible file.
    .DESCRIPTION
        Not exported.
        A file that cannot be read or written is recorded and stepped over,
        so the caller can name every gap at once - see Rename-Token.
    .OUTPUTS
        A PSCustomObject with Edited (how many files were rewritten),
        Warning (one line per file skipped as binary),
        and Failed (one "<path> - <reason>" line
        per file that could not be updated).
    #>
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
        [string[]]$SkipExtension
    )

    $edited = 0
    $warnings = [List[string]]::new()
    $failed = [List[string]]::new()
    $files = @($Item | Where-Object {
            -not $_.PSIsContainer -and $_.Extension -notin $SkipExtension
        })

    foreach ($file in $files) {
        try {
            $before = [File]::ReadAllText($file.FullName)
            if (-not $before.Contains($From)) {
                continue
            }

            if ($before.Contains([char]0)) {
                $warnings.Add("Skipped binary content: $($file.FullName)")
                continue
            }

            if (Update-FileToken -Path $file.FullName -From $From -To $To) {
                $edited++
            }
        }
        catch {
            $failed.Add("$($file.FullName) - $($_.Exception.Message)")
        }
    }

    return [PSCustomObject]@{
        Edited  = $edited
        Warning = @($warnings)
        Failed  = @($failed)
    }
}
