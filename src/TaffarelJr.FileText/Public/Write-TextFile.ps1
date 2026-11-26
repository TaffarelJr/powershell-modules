using namespace System.Text

function Write-TextFile {
    <#
    .SYNOPSIS
        Writes text back with the encoding the file already had,
        and with -Line its CRLF or LF line ending too.
    .DESCRIPTION
        Rewriting a file through PowerShell's own defaults is lossy: it writes
        UTF-8 without a byte order mark, so a file that had one loses it, and
        it ends every line with this process's line ending. This keeps the
        file as it was except for its text.

        -Line is for text built up a line at a time: the lines are joined with
        the line ending the file already uses, and the file ends with exactly
        one. -Content is for text already assembled, written exactly as given,
        line endings included; only the encoding is matched.

        -LikeFilePath supplies the encoding and the line ending when Path does
        not exist yet, or is empty and so has nothing to preserve: a file only
        now being created, that should still come out looking like a sibling
        already on disk. With neither on disk to match, the file is UTF-8
        without a BOM, and its line ending is this process's own.

        The encoding to keep comes from the file's byte order mark. A file
        with no mark that is not valid UTF-8 either - Windows-1252, say - has
        no encoding to read off it, so writing over it, or copying from it
        with -LikeFilePath, throws unless -Encoding says what to write.

        The text is encoded in full before the file is opened, so text the
        encoding cannot hold - a lone surrogate, or an accented letter for
        -Encoding ASCII - throws and leaves an existing file exactly as it
        was, and creates no new one. An existing file is written in place
        rather than replaced, so it keeps its attributes: a hidden or system
        file stays one, and can be written at all.

        Anything that stops the write is a terminating error for that call.
        Everything checked above, and a failure to open the file, is raised
        before the file is changed; a failure while writing it, after it is
        open, can leave it partly written. A file that cannot be opened - its
        folder is missing, another program holds it, or it is read-only -
        throws "Cannot write '<path>':" followed by the reason. A folder that
        is missing is made only when -CreateDirectory says so.

        With -WhatIf nothing is changed and nothing is returned.

        With -Verbose, names the file, the encoding and the size of what is
        written, never its text.
    .PARAMETER Path
        The file to write. A relative path is relative to PowerShell's current
        location.
    .PARAMETER Line
        Joined with the resolved line ending and given exactly one trailing
        one. A line break inside a line - CRLF, LF, or a lone CR - becomes the
        resolved ending too, so the file never ends up with two kinds; one
        break at the very end of the last line is dropped, since the file's
        own trailing ending stands in for it. No lines at all write no text.
        Use this, not -Content, for anything built up a line at a time.
        The resolved ending is the one Get-LineEnding reads off the file,
        CRLF or LF, never a lone CR: a file whose lines end in a lone CR is
        rewritten with this process's own line ending. Also accepted as
        -Lines.
    .PARAMETER Content
        Written exactly as given, line endings included: only the encoding is
        matched, never the line ending.
        For the rarer case where the caller has already assembled the whole
        file, trailing line ending included.
    .PARAMETER LikeFilePath
        A sibling file to copy the encoding and line ending from,
        when -Path itself does not exist yet or is empty.
    .PARAMETER Encoding
        Writes with this encoding whatever the file had, for a caller that
        means to change it - or to put back one Read-TextFile was given.
        Takes a System.Text.Encoding object, not a name like 'utf8'. Its byte
        order mark, if it has one, is written; text it cannot hold throws
        rather than being written with a stand-in character.
    .PARAMETER CreateDirectory
        Makes any folder missing on the way to Path before the file is
        written, as New-Item -Force does. Without it a missing folder is an
        error. With -WhatIf no folder is made.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The text is given with -Line or -Content.
    .OUTPUTS
        None. The text is written to the file.
    .EXAMPLE
        Write-TextFile -Path ./notes.txt -Line 'first', 'second'

        Writes the two lines, in notes.txt's own encoding and line ending if it
        exists, and in UTF-8 with this process's line ending if it does not.
    .EXAMPLE
        $file = Read-TextFile -Path ./README.md
        $text = $file.Content -replace 'old', 'new'
        Write-TextFile -Path ./README.md -Content $text

        Changes a word and keeps everything else about README.md.
    .EXAMPLE
        Write-TextFile -Path ./build/new.txt -Content 'text' -CreateDirectory

        Makes the build folder if it is missing, and writes the file in it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Read-TextFile
    .LINK
        Get-FileEncoding
    .LINK
        Get-LineEnding
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Lines')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Lines')]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [Alias('Lines')]
        [string[]]$Line,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [AllowEmptyString()]
        [string]$Content,

        [string]$LikeFilePath,

        [Encoding]$Encoding,

        [switch]$CreateDirectory
    )

    $ErrorActionPreference = 'Stop'

    if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
    }

    if (-not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
    }

    if (-not $PSBoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $full = Resolve-TextFilePath -Path $Path
    if ($PSBoundParameters.ContainsKey('LikeFilePath')) {
        $reference = Resolve-WriteReference -Path $full `
            -LikeFilePath $LikeFilePath
    }
    else {
        $reference = Resolve-WriteReference -Path $full
    }

    $chosen = Resolve-WriteEncoding -Reference $reference -Encoding $Encoding

    $body = $Content
    if ($PSCmdlet.ParameterSetName -eq 'Lines') {
        $lineEnding = [Environment]::NewLine
        if ($reference) {
            $decoded = Read-DecodedText -Path $reference -Encoding $Encoding
            $lineEnding = Get-LineEnding -Content $decoded.Content
        }

        $body = Format-TextBody -Line $Line -LineEnding $lineEnding
    }

    $preamble = $chosen.GetPreamble()
    $payload = $chosen.GetBytes($body)
    if (-not $PSCmdlet.ShouldProcess($full, 'Write file')) {
        return
    }

    $size = $preamble.Length + $payload.Length
    Write-Verbose "Writing $size bytes to '$full' as $($chosen.WebName)."
    Write-FileByte -Path $full -Preamble $preamble -Payload $payload `
        -CreateDirectory:$CreateDirectory
}
