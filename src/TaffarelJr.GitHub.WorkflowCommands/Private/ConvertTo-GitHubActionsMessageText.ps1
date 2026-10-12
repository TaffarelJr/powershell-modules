function ConvertTo-GitHubActionsMessageText {
    <#
    .SYNOPSIS
        Returns the text of a message a logging command was given, whether
        as text or as a piped object.
    .DESCRIPTION
        Not exported. Shared by Write-GitHubActionsDebug and, through
        Write-GitHubActionsAnnotation, Write-GitHubActionsNotice, -Warning,
        and -Error, so all four read a piped object the same way. Text is
        returned as it is. A Select-String match gives its matched line, and
        an error record its message. Any other object gives its Message
        property as text, so a number is the digits and not the object's own
        text, and throws without one.
    .PARAMETER Message
        The text, or the piped object that carries it.
    .OUTPUTS
        The message's text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [object]$Message
    )

    # Named as text: the Utility commands' assembly that defines MatchInfo may
    # not be loaded yet in a new process, and a type literal would then throw.
    if ($Message.GetType().FullName -eq 'Microsoft.PowerShell.Commands.MatchInfo') {
        return [string]$Message.PSObject.Properties['Line'].Value
    }

    if ($Message -is [string]) {
        return $Message
    }

    if ($Message -is [System.Management.Automation.ErrorRecord]) {
        return "$Message"
    }

    $property = $Message.PSObject.Properties['Message']
    if ($null -eq $property) {
        throw "A piped object needs a Message property, or give the text: $($Message.GetType().Name)."
    }

    if ($null -eq $property.Value) {
        throw "A piped object's Message property is `$null: give it the text."
    }

    return [string]$property.Value
}
