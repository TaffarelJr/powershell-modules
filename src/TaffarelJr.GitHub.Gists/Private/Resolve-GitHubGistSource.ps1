using namespace System.IO

function Resolve-GitHubGistSource {
    <#
    .SYNOPSIS
        Returns each file a New-GitHubGist -Path value names: its full path,
        and how a message is to name it.
    .DESCRIPTION
        A value is a PowerShell path, relative to PowerShell's location: a
        wildcard (* ? [ ]) is expanded to the files it matches, hidden ones
        aside, and a value with none - or with each one escaped with a
        backtick - names one file. A folder is never a source, and neither
        is anything off the file system.

        A file named outright keeps the name the file system has for it,
        not the one typed: on a case-insensitive file system 'notes.md'
        opens Notes.md, and the gist file is to be called Notes.md.
    .PARAMETER Path
        One -Path value.
    .OUTPUTS
        One object per file, in the order PowerShell lists them: Path, its
        full path; Source, the value as typed (quoted) for a file named
        outright, or the full path (quoted) for one a wildcard matched. Either
        has any URL credential in it hidden, as Hide-UrlCredential does, so
        a message may show it.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $shown = Hide-UrlCredential -Text $Path
    if ([WildcardPattern]::ContainsWildcardCharacters($Path)) {
        Resolve-GitHubPath -Path $Path | Out-Null
        $items = @(Get-Item -Path $Path -ErrorAction Ignore)
        $files = @($items | Where-Object { $_ -is [FileInfo] })
        if ($files.Count -eq 0) {
            throw "'$shown' matches no file."
        }

        foreach ($file in $files) {
            $shownFull = Hide-UrlCredential -Text $file.FullName
            [PSCustomObject]@{
                Path   = $file.FullName
                Source = "'$shownFull'"
            }
        }

        return
    }

    $full = Resolve-GitHubPath -Path ([WildcardPattern]::Unescape($Path))
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "'$shown' is not a file."
    }

    [PSCustomObject]@{
        Path   = Get-GitHubGistLocalFile -Path $full -Source "'$shown'"
        Source = "'$shown'"
    }
}
