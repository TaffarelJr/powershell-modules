#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput
$convert = {
    param($record)
    & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Do-Thing' } $record
}
$catchFrom = {
    param($block)
    try {
        & $block
    }
    catch {
        $_
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed exception, thrown
$thrown = & $catchFrom { throw [ArgumentException]::new('bad value', 'Name') }

# Act
$result = & $convert $thrown

# Assert
Assert-Equal -Expected 'ArgumentException' -Actual $result.FullyQualifiedErrorId `
    -Message 'An exception with no ID of its own gets its type name as the ID'
Assert-Equal -Expected ([ErrorCategory]::InvalidArgument) -Actual $result.CategoryInfo.Category `
    -Message 'and an argument exception is an invalid argument'
Assert-That -Condition ([object]::ReferenceEquals($thrown.Exception, $result.Exception)) `
    -Message 'and the failure keeps its own exception, so its message is unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a thrown string, which has the message as its ID and no category of its own
$thrown = & $catchFrom { throw 'plain failure' }

# Act
$result = & $convert $thrown

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $result.FullyQualifiedErrorId `
    -Message 'A thrown string gets the type name of its exception as the ID, not its own text'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $result.CategoryInfo.Category `
    -Message 'and is an invalid operation'
Assert-Equal -Expected 'plain failure' -Actual $result.Exception.Message `
    -Message 'and its message is unchanged'
Assert-Equal -Expected 'plain failure' -Actual $result.TargetObject `
    -Message 'and its target is the one the failure had'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet, which already has an ID and a category
$missing = Join-Path ([IO.Path]::GetTempPath()) "commanderror-$([Guid]::NewGuid())"
$native = & $catchFrom { Get-Item -LiteralPath $missing -ErrorAction Stop }

# Act
$result = & $convert $native

# Assert
Assert-Equal -Expected $native.FullyQualifiedErrorId -Actual $result.FullyQualifiedErrorId `
    -Message 'An error from a built-in cmdlet keeps its ID'
Assert-Equal -Expected ([ErrorCategory]::ObjectNotFound) -Actual $result.CategoryInfo.Category `
    -Message 'and its category'
Assert-Equal -Expected $missing -Actual $result.TargetObject -Message 'and its target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record that was built with an ID and a category of its own
$target = [PSCustomObject]@{ Name = 'the target' }
$exception = [InvalidOperationException]::new('no connection')
$record = [ErrorRecord]::new($exception, 'ConnectionLost', [ErrorCategory]::ResourceUnavailable, $target)

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'ConnectionLost' -Actual $result.FullyQualifiedErrorId -Message 'A real ID is kept'
Assert-Equal -Expected ([ErrorCategory]::ResourceUnavailable) -Actual $result.CategoryInfo.Category `
    -Message 'and so is a real category'
Assert-That -Condition ([object]::ReferenceEquals($target, $result.TargetObject)) `
    -Message 'and the very target object, not a copy'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID with white space in it is a sentence, not an ID
$record = [ErrorRecord]::new($exception, 'No connection to the host', [ErrorCategory]::NotSpecified, $null)

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'InvalidOperationException' -Actual $result.FullyQualifiedErrorId `
    -Message 'An ID with white space in it is replaced by the exception type name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one failure of each kind, with no category of its own
$cases = @(
    @{ Exception = [ArgumentNullException]::new('Name'); Expected = [ErrorCategory]::InvalidArgument }
    @{ Exception = [ItemNotFoundException]::new('item'); Expected = [ErrorCategory]::ObjectNotFound }
    @{ Exception = [IO.FileNotFoundException]::new('file'); Expected = [ErrorCategory]::ObjectNotFound }
    @{ Exception = [IO.DirectoryNotFoundException]::new('folder'); Expected = [ErrorCategory]::ObjectNotFound }
    @{ Exception = [UnauthorizedAccessException]::new('denied'); Expected = [ErrorCategory]::PermissionDenied }
    @{ Exception = [TimeoutException]::new('slow'); Expected = [ErrorCategory]::OperationTimeout }
    @{ Exception = [InvalidOperationException]::new('state'); Expected = [ErrorCategory]::InvalidOperation }
    @{ Exception = [NotSupportedException]::new('unsupported'); Expected = [ErrorCategory]::InvalidOperation }
)

foreach ($case in $cases) {
    foreach ($given in [ErrorCategory]::NotSpecified, [ErrorCategory]::OperationStopped) {
        # Act
        $record = [ErrorRecord]::new($case.Exception, 'AnyId', $given, $null)
        $result = & $convert $record

        # Assert
        Assert-Equal -Expected $case.Expected -Actual $result.CategoryInfo.Category `
            -Message "$($case.Exception.GetType().Name) with category $given becomes $($case.Expected)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a category a caller can act on is never replaced
$exception = [IO.FileNotFoundException]::new('file')
$record = [ErrorRecord]::new($exception, 'AnyId', [ErrorCategory]::AuthenticationError, $null)

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected ([ErrorCategory]::AuthenticationError) -Actual $result.CategoryInfo.Category `
    -Message 'A category other than NotSpecified and OperationStopped is kept whatever the exception'

exit (Complete-TestRun)
