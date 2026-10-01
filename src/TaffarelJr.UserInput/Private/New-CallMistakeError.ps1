using namespace System.Management.Automation

function New-CallMistakeError {
    <#
    .SYNOPSIS
        Builds the error for a mistake in how a function was called, as
        opposed to a bad answer.
    .DESCRIPTION
        Not exported. Thrown with ThrowTerminatingError, the record's
        FullyQualifiedErrorId is the ErrorId and the function's name, and an
        id listed in the module's CallMistakeErrorId tells Invoke-InputRetry
        that asking again cannot help.
    .PARAMETER Message
        What is wrong and what to do about it.
    .PARAMETER ErrorId
        The id that marks this mistake.
    .PARAMETER TargetObject
        The value that is wrong.
    .OUTPUTS
        An ErrorRecord in the InvalidArgument category.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Builds an error record in memory; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$ErrorId,

        [AllowNull()]
        [object]$TargetObject
    )

    return [ErrorRecord]::new(
        [ArgumentException]::new($Message),
        $ErrorId,
        [ErrorCategory]::InvalidArgument,
        $TargetObject)
}
