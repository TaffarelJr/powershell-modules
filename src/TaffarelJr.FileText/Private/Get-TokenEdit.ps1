function Get-TokenEdit {
    <#
    .SYNOPSIS
        Works out what replacing a token in one file would do, without
        changing the file.
    .DESCRIPTION
        Not exported. The file is read once. A file whose first 8 KB hold a
        NUL is binary content, and is never decoded: its bytes are searched
        for the token in each Unicode encoding instead. That is also how
        UTF-16 or UTF-32 text with no byte order mark is caught, as Binary
        rather than as a file without the token. A file without the token is
        left alone whatever it holds. Text that has the token but is not valid
        in its encoding throws, because rewriting it would replace each such
        character for good.
    .PARAMETER Path
        The full path of the file, as Resolve-TextFilePath returns it.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with. May be empty.
    .OUTPUTS
        A PSCustomObject whose Status is 'Edit', with the new Content and the
        Encoding to write it in; 'NoToken', for a file without the token or
        where replacing it would change nothing; or 'Binary', for content
        with a NUL that holds the token.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$To
    )

    if (Test-BinaryHead -Path $Path) {
        if (Test-ByteToken -Path $Path -Token $From) {
            return [PSCustomObject]@{ Status = 'Binary' }
        }

        return [PSCustomObject]@{ Status = 'NoToken' }
    }

    $file = Read-DecodedText -Path $Path
    if (-not $file.Content.Contains($From)) {
        return [PSCustomObject]@{ Status = 'NoToken' }
    }

    if ($file.Content.Contains([char]0)) {
        return [PSCustomObject]@{ Status = 'Binary' }
    }

    if ($file.Problem) {
        throw $file.Problem
    }

    $replaced = $file.Content.Replace($From, $To)
    if ([string]::Equals($replaced, $file.Content, 'Ordinal')) {
        return [PSCustomObject]@{ Status = 'NoToken' }
    }

    return [PSCustomObject]@{
        Status   = 'Edit'
        Content  = $replaced
        Encoding = $file.Encoding
    }
}
