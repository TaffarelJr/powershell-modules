function Resolve-GitHubActionsFilePath {
    <#
    .SYNOPSIS
        Returns the full path of the runner file a GITHUB_* variable names,
        after checking the file is there.
    .DESCRIPTION
        Not exported. Shared by every function that writes one of the
        runner's files.

        A relative path is taken from PowerShell's location, not from the
        process's working directory, which is what .NET would use. The
        runner creates each file before the step starts, so a missing one
        means a stale or mistyped path: writing would create a file the
        runner never reads.
    .PARAMETER Variable
        The variable naming the file, such as GITHUB_OUTPUT.
    .OUTPUTS
        The file's full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GITHUB_ENV', 'GITHUB_OUTPUT', 'GITHUB_PATH', 'GITHUB_STATE', 'GITHUB_STEP_SUMMARY')]
        [string]$Variable
    )

    $value = [Environment]::GetEnvironmentVariable($Variable)
    if (-not $value) {
        throw "$Variable is not set - this must run inside a GitHub Actions step."
    }

    $shownValue = Hide-UrlCredential -Text $value
    $path = Resolve-GitHubActionsFileSystemPath -Path $value -Subject "$Variable is '$shownValue'" -Kind 'file'

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $shownPath = Hide-UrlCredential -Text $path
        throw ("$Variable points at '$shownPath', which is not a file; " +
            'the runner creates it for each step, so check the variable''s value.')
    }

    return $path
}
