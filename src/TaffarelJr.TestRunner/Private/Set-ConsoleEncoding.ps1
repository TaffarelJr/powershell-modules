function Set-ConsoleEncoding {
    <#
    .SYNOPSIS
        Sets the encoding the console decodes output with.
    .DESCRIPTION
        Throws an IOException in a host that has no console to set it on.
    .PARAMETER Encoding
        The encoding to set.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Sets the console encoding for the test run, which Invoke-TestRun restores when it ends.')]
    param(
        [Parameter(Mandatory)]
        [Text.Encoding]$Encoding
    )

    [Console]::OutputEncoding = $Encoding
}
