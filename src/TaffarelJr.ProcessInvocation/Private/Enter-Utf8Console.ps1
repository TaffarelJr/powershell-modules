using namespace System.IO
using namespace System.Text
using namespace System.Threading

function Enter-Utf8Console {
    <#
    .SYNOPSIS
        Pins the console's output and input encodings to UTF-8 for the
        calling command.
    .DESCRIPTION
        Not exported. A child writes to the console's output code page, and
        reads the text it is sent on standard input with the input code page,
        so both are pinned: the child then writes UTF-8 and reads the UTF-8
        it is sent.

        The encoding is process-wide, so concurrent callers -
        ForEach-Object -Parallel runspaces, say - share one pin: the first
        in records the original encoding and the last out, through
        Exit-Utf8Console, restores it. Pinning and restoring per call lets an
        overlapping call restore a value another call already pinned,
        leaving UTF-8 behind, or restore the original under a call that is
        still decoding.

        Nothing is changed when the console is already UTF-8, or when there
        is no console at all - a service, a GUI host, a detached process -
        since then there is no console code page for a child to inherit.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'With no console there is no code page to pin, so nothing was changed.')]
    param()

    $gate = Get-ConsoleEncodingGate
    [Monitor]::Enter($gate)
    try {
        if ($gate.Depth -eq 0) {
            $gate.Original = $null
            $gate.OriginalInput = $null
            $current = [Console]::OutputEncoding
            if ($current.CodePage -ne 65001) {
                try {
                    [Console]::OutputEncoding = [UTF8Encoding]::new($false)
                    $gate.Original = $current
                }
                catch [IOException] {
                    # No console to set the code page of: nothing was pinned,
                    # so Original stays $null and Exit-Utf8Console restores
                    # nothing.
                }
            }

            $currentInput = [Console]::InputEncoding
            if ($currentInput.CodePage -ne 65001) {
                try {
                    [Console]::InputEncoding = [UTF8Encoding]::new($false)
                    $gate.OriginalInput = $currentInput
                }
                catch [IOException] {
                    # No console either way: nothing was pinned.
                }
            }
        }

        $gate.Depth++
    }
    finally {
        [Monitor]::Exit($gate)
    }
}
