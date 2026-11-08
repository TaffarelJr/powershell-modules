function Invoke-GitHubReleaseChange {
    <#
    .SYNOPSIS
        Runs a gh release command that creates or edits a release, and
        returns the release's URL.
    .DESCRIPTION
        Notes, when given, are written to a temporary file that gh reads
        with --notes-file, so they arrive exactly as given: on standard
        input they would gain a trailing newline. An empty string is an
        empty file, which clears the notes.
    .PARAMETER Activity
        What the call does, for a failure message.
    .PARAMETER Option
        The command and its options, ahead of the --.
    .PARAMETER Operand
        The tag and any assets, after the --.
    .PARAMETER Repository
        The repository, as gh's --repo takes it.
    .PARAMETER Notes
        The release notes. Leave it out to send none.
    .OUTPUTS
        The URL gh prints, or nothing when it prints none.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string[]]$Option,

        [Parameter(Mandatory)]
        [string[]]$Operand,

        [string]$Repository,

        [AllowEmptyString()]
        [string]$Notes
    )

    if ($PSBoundParameters.ContainsKey('Notes')) {
        $out = Use-GitHubTextFile -Text $Notes -ScriptBlock {
            param($Path)
            $arguments = @($Option) + '--notes-file' + $Path + '--' + $Operand
            Invoke-GitHubCommand -Activity $Activity -Arguments $arguments -Repository $Repository
        }
    }
    else {
        $arguments = @($Option) + '--' + $Operand
        $out = Invoke-GitHubCommand -Activity $Activity -Arguments $arguments -Repository $Repository
    }

    $urls = @($out | Where-Object { $_ -match '^https?://' })
    if ($urls.Count -eq 0) {
        return
    }

    return $urls[0]
}
