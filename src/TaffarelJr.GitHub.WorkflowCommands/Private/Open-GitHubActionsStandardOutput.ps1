function Open-GitHubActionsStandardOutput {
    <#
    .SYNOPSIS
        Opens the process's standard output as a raw stream.
    .DESCRIPTION
        Not exported. Write-GitHubActionsLine opens the stream through this,
        so a test can hand it one it can read back.
    .OUTPUTS
        The stream. The caller disposes it.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.Stream])]
    param()

    return [Console]::OpenStandardOutput()
}
