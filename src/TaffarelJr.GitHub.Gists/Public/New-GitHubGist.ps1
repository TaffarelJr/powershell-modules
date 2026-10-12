function New-GitHubGist {
    <#
    .SYNOPSIS
        Creates a gist from one or more local files, or from piped
        content.
    .DESCRIPTION
        gh defaults a new gist to secret; pass -Public to make it public.
    .PARAMETER Path
        The local files to include.
    .PARAMETER Content
        Content to use as the gist's one file, instead of -Path.
    .PARAMETER FileName
        The file name to give -Content. Required with -Content; with
        -Path, names a single file read from standard input instead of
        from disk.
    .PARAMETER Description
        A description for the gist.
    .PARAMETER Public
        Makes the gist public instead of secret.
    .OUTPUTS
        The new gist's URL.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Path')]
        [string[]]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [string]$Content,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [string]$FileName,

        [string]$Description,

        [switch]$Public
    )

    $arguments = @('gist', 'create')
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $arguments += @($Path)
    }

    if ($FileName) {
        $arguments += @('--filename', $FileName)
    }

    if ($Description) {
        $arguments += @('--desc', $Description)
    }

    if ($Public) {
        $arguments += '--public'
    }

    $extra = @{}
    if ($PSCmdlet.ParameterSetName -eq 'Content') {
        $extra['StdIn'] = $Content
    }

    $out = Invoke-GitHubCommand -Activity 'Creating the gist' -Arguments $arguments @extra
    return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
}
