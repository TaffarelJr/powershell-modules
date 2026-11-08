using namespace System.Diagnostics.CodeAnalysis

function Remove-IndentLevel {
    <#
    .SYNOPSIS
        Takes the most recent level off the indent stack.
    .DESCRIPTION
        Not exported. One of the helpers that own the indent stack.
    .OUTPUTS
        True when a level was taken off; false when the stack was empty.
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Changes the indentation this module keeps in memory; nothing outside the process changes.')]
    [OutputType([bool])]
    param()

    if ($script:IndentStack.Count -eq 0) {
        return $false
    }

    [void]$script:IndentStack.Pop()
    return $true
}
