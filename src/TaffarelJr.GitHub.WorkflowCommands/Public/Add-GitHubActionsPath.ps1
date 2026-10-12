function Add-GitHubActionsPath {
    <#
    .SYNOPSIS
        Prepends a directory to PATH for the rest of this step and every
        step after it.
    .DESCRIPTION
        Also prepends it to this process's own PATH immediately, since
        the file this writes to only takes effect for steps that start
        after the current one ends.
    .PARAMETER Path
        The directory to add.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidatePattern('\S')]
        [string]$Path
    )

    process {
        if (-not $env:GITHUB_PATH) {
            throw 'GITHUB_PATH is not set - this must run inside a GitHub Actions step.'
        }

        [System.IO.File]::AppendAllText($env:GITHUB_PATH, "$Path`n", [System.Text.UTF8Encoding]::new($false))
        $env:PATH = $Path + [System.IO.Path]::PathSeparator + $env:PATH
    }
}
