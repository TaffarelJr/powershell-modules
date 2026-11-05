function Edit-TextFileToken {
    <#
    .SYNOPSIS
        Replaces a token in one file, and says what happened.
    .DESCRIPTION
        Not exported. The shared body of Update-FileToken and the content pass
        of Rename-Token, which differ only in what they do with the answer.
        The file is read once and written once, with the encoding it was read
        in; line endings survive because the whole text is written as it was.
        A file without the token is left alone whatever it holds. One that has
        the token but cannot be rewritten safely - binary, or text in an
        encoding that would not survive - throws or is declined, as below.

        A file whose first 8 KB hold a NUL is binary content, and is never
        decoded: its bytes are searched for the token as UTF-8, UTF-16, and
        UTF-32 instead. That is also how UTF-16 or UTF-32 text without a byte
        order mark is caught - as Binary, rather than as a file that does not
        hold the token.
    .PARAMETER Path
        The file to edit.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with. May be empty.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet, whose ShouldProcess is asked with the
        file's full path and the action once the file is known to need
        rewriting, so -WhatIf and -Confirm name only such files. When it
        answers no, the file is left alone. When it cannot ask - no one can
        answer a -Confirm prompt - its error is thrown with the error ID
        TextFileApprovalFailed, so a caller that steps over a file's failure
        can tell it apart and stop.
    .OUTPUTS
        'Edited', 'NoToken' - the token is absent, or replacing it would
        change nothing - 'Binary' - a NUL in the content, the reliable mark of
        binary content - or 'Declined' when ShouldProcess said no.
        Throws for text that is not valid in its encoding.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Asks the public caller''s ShouldProcess, passed in as -Cmdlet.')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$To,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $full = Resolve-TextFilePath -Path $Path -MustExist
    if (Test-BinaryHead -Path $full) {
        if (Test-ByteToken -Path $full -Token $From) {
            return 'Binary'
        }

        return 'NoToken'
    }

    $file = Read-DecodedText -Path $full
    if (-not $file.Content.Contains($From)) {
        return 'NoToken'
    }

    if ($file.Content.Contains([char]0)) {
        return 'Binary'
    }

    if ($file.Problem) {
        throw $file.Problem
    }

    $replaced = $file.Content.Replace($From, $To)
    if ([string]::Equals($replaced, $file.Content, 'Ordinal')) {
        return 'NoToken'
    }

    $approved = try {
        $Cmdlet.ShouldProcess($full, "Replace '$From'")
    }
    catch {
        throw [System.Management.Automation.ErrorRecord]::new(
            $_.Exception,
            'TextFileApprovalFailed',
            [System.Management.Automation.ErrorCategory]::OperationStopped,
            $full)
    }

    if (-not $approved) {
        return 'Declined'
    }

    Write-TextFile `
        -Path $full `
        -Content $replaced `
        -Encoding $file.Encoding `
        -Confirm:$false
    return 'Edited'
}
