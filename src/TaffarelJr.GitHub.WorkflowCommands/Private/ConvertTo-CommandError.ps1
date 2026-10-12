using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO
using namespace System.Management.Automation

function ConvertTo-CommandError {
    <#
    .SYNOPSIS
        Returns the error record a public function raises when something in
        it failed.
    .DESCRIPTION
        Not exported. Keeps the failure's own exception and target, gives it
        an error ID that names the exception type and a category a caller can
        act on, and leaves a record that already has a real ID and category
        (an error from a built-in cmdlet) as it is.
    .PARAMETER ErrorRecord
        The failure that was caught.
    .PARAMETER Command
        The name of the public function that caught it.
    .OUTPUTS
        The record to pass to ThrowTerminatingError.
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'Part of the call every public function makes; PowerShell appends the command name to the ID.')]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory)]
        [string]$Command
    )

    $exception = $ErrorRecord.Exception
    $category = $ErrorRecord.CategoryInfo.Category
    if ($category -in 'NotSpecified', 'OperationStopped') {
        $category = switch ($exception) {
            { $_ -is [ArgumentException] } { 'InvalidArgument'; break }
            { $_ -is [ItemNotFoundException] -or
                $_ -is [FileNotFoundException] -or
                $_ -is [DirectoryNotFoundException] } { 'ObjectNotFound'; break }
            { $_ -is [UnauthorizedAccessException] } { 'PermissionDenied'; break }
            { $_ -is [TimeoutException] } { 'OperationTimeout'; break }
            default { 'InvalidOperation' }
        }
    }

    $errorId = $ErrorRecord.FullyQualifiedErrorId
    if ($errorId -ceq $exception.Message -or $errorId -match '\s') {
        $errorId = $exception.GetType().Name
    }

    return [ErrorRecord]::new($exception, $errorId, $category, $ErrorRecord.TargetObject)
}
