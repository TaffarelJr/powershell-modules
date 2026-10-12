function Find-GitHubCode {
    <#
    .SYNOPSIS
        Searches GitHub for code.
    .PARAMETER Query
        Search keywords.
    .PARAMETER Owner
        Only code owned by one of these users or organizations.
    .PARAMETER Repository
        Only code in this repository, in OWNER/REPO form.
    .PARAMETER Language
        Only files in this language.
    .PARAMETER Filename
        Only files with this name.
    .PARAMETER Extension
        Only files with this extension.
    .PARAMETER Match
        Restricts the search to file contents or file paths: file or
        path.
    .PARAMETER Size
        A size range in kilobytes.
    .PARAMETER Limit
        The most results to fetch. gh's default is 30.
    .OUTPUTS
        One object per match - Path, Sha, Url, Repository, TextMatches -
        always an array.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [string[]]$Owner,

        [string]$Repository,

        [string]$Language,

        [string]$Filename,

        [string]$Extension,

        [ValidateSet('file', 'path')]
        [string[]]$Match,

        [string]$Size,

        [int]$Limit
    )

    $arguments = @('search', 'code', $Query, '--json', 'path,repository,sha,textMatches,url')
    foreach ($name in $Owner) {
        $arguments += @('--owner', $name)
    }

    if ($Language) {
        $arguments += @('--language', $Language)
    }

    if ($Filename) {
        $arguments += @('--filename', $Filename)
    }

    if ($Extension) {
        $arguments += @('--extension', $Extension)
    }

    foreach ($field in $Match) {
        $arguments += @('--match', $field)
    }

    if ($Size) {
        $arguments += @('--size', $Size)
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Searching code' -Arguments $arguments -Repository $Repository
    $results = ConvertFrom-GitHubJson -Lines $out
    return , @($results)
}
