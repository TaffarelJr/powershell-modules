using namespace System.Threading

function Exit-Utf8Console {
    <#
    .SYNOPSIS
        Lets go of the UTF-8 pin Enter-Utf8Console took, restoring the
        original encoding when the last holder lets go.
    .DESCRIPTION
        Not exported. Call it exactly once for each Enter-Utf8Console, from a
        finally block. Only an encoding Enter-Utf8Console really changed is
        restored.
    #>
    param()

    $gate = Get-ConsoleEncodingGate
    [Monitor]::Enter($gate)
    try {
        $gate.Depth--
        if ($gate.Depth -eq 0) {
            if ($null -ne $gate.Original) {
                [Console]::OutputEncoding = $gate.Original
                $gate.Original = $null
            }

            if ($null -ne $gate.OriginalInput) {
                [Console]::InputEncoding = $gate.OriginalInput
                $gate.OriginalInput = $null
            }
        }
    }
    finally {
        [Monitor]::Exit($gate)
    }
}
