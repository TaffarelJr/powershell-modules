using namespace System.IO
using namespace System.Text

function Write-TextFile {
    <#
    .SYNOPSIS
        Writes text back with the encoding the file already had, and with
        -Line its CRLF or LF line ending too.
    .DESCRIPTION
        -LikeFilePath supplies both when Path does not exist yet, or is empty
        and so has nothing to preserve: a file only now being created,
        that should still come out looking like a sibling already on disk.
        Falls back to UTF-8 without a BOM and this process's own line ending
        only when neither Path nor LikeFilePath has anything on disk to match.

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
        None. Nothing can be piped in.
    .OUTPUTS
        None. The text is written to the file.
    .EXAMPLE
        Write-TextFile -Path ./notes.txt -Line 'first', 'second'

        Writes two lines to notes.txt, in the encoding and line ending it
        already uses, or in UTF-8 and this process's line ending when it is
        new.
    .EXAMPLE
        Write-TextFile -Path ./src/New.cs -Line $lines `
            -LikeFilePath ./src/Existing.cs

        Creates New.cs with the encoding and line ending Existing.cs already
        uses.
    .EXAMPLE
        Write-TextFile -Path ./out/logs/run.txt -Line $lines -CreateDirectory

        Writes run.txt, making the out and logs folders first when they are
        not there.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Read-TextFile
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

    try {
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
        $reference = $null
        $candidates = @($full)
        if ($LikeFilePath) {
            $candidates += Resolve-TextFilePath -Path $LikeFilePath
        }

        foreach ($candidate in $candidates) {
            if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and ([FileInfo]$candidate).Length -gt 0) {
                $reference = $candidate
                break
            }
        }

        $encodingGiven = $PSBoundParameters.ContainsKey('Encoding')
        $isLines = $PSCmdlet.ParameterSetName -eq 'Lines'
        $decoded = $null
        if ($reference -and ($isLines -or -not $encodingGiven)) {
            $decoded = Read-DecodedText -Path $reference -Encoding $Encoding
        }

        $chosen = [UTF8Encoding]::new($false, $true)
        if ($encodingGiven) {
            $chosen = Get-StrictEncoding -Encoding $Encoding
        }
        elseif ($decoded) {
            if ($decoded.Problem -and $decoded.Encoding.GetPreamble().Length -eq 0) {
                throw ("Cannot tell what encoding '$reference' is in: it has no byte order mark " +
                    'and is not valid UTF-8. Pass -Encoding to say which encoding to write.')
            }

            $chosen = $decoded.Encoding
        }

        $body = $Content
        if ($isLines) {
            $eol = [Environment]::NewLine
            if ($decoded) {
                $eol = Get-LineEnding -Content $decoded.Content
            }

            $body = ''
            if ($Line.Count -gt 0) {
                $all = [string[]]$Line.Clone()
                $all[-1] = $all[-1] -replace '(\r\n|\r|\n)\z', ''
                $body = (($all -join "`n") -replace '\r\n|\r|\n', $eol) + $eol
            }
        }

        $preamble = $chosen.GetPreamble()
        $payload = $chosen.GetBytes($body)
        if (-not $PSCmdlet.ShouldProcess($full, 'Write file')) {
            return
        }

        $size = $preamble.Length + $payload.Length
        Write-Verbose "Writing $size bytes to '$full' as $($chosen.WebName)."
        try {
            if ($CreateDirectory) {
                $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($full))
            }

            $stream = [File]::Open($full, [FileMode]::OpenOrCreate, [FileAccess]::Write, [FileShare]::Read)
        }
        catch {
            throw "Cannot write '$full': $($_.Exception.GetBaseException().Message)"
        }

        try {
            $stream.Write($preamble, 0, $preamble.Length)
            $stream.Write($payload, 0, $payload.Length)
            $stream.SetLength($stream.Position)
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
