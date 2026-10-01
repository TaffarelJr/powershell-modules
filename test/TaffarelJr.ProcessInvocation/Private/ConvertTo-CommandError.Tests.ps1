#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Get-Module TaffarelJr.ProcessInvocation

function Get-CommandError {
    <#
    .SYNOPSIS
        Runs ConvertTo-CommandError in the module on a record.
    .DESCRIPTION
        Not exported - a test-only fixture. The converter is private.
    .PARAMETER ErrorRecord
        The failure to convert.
    .OUTPUTS
        The record the converter returns.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    return & $module {
        param($record)
        ConvertTo-CommandError -ErrorRecord $record -Command 'Test-Command'
    } $ErrorRecord
}

function New-FailureRecord {
    <#
    .SYNOPSIS
        Returns an error record for an exception, with an ID and a category.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Exception
        The exception the record carries.
    .PARAMETER ErrorId
        The record's ID.
    .PARAMETER Category
        The record's category.
    .PARAMETER Target
        The record's target.
    .OUTPUTS
        The error record.
    #>
    param(
        [Parameter(Mandatory)]
        [Exception]$Exception,

        [string]$ErrorId = 'SomeError',

        [System.Management.Automation.ErrorCategory]$Category = 'NotSpecified',

        [object]$Target
    )

    return [System.Management.Automation.ErrorRecord]::new($Exception, $ErrorId, $Category, $Target)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed exception thrown by a script, which PowerShell reports
# with its message as the ID and no target
$typed = try { throw [ArgumentException]::new('bad value') } catch { $_ }

# Act
$converted = Get-CommandError -ErrorRecord $typed

# Assert
Assert-Equal -Expected 'ArgumentException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An ID that is only the message becomes the exception type''s name'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'An argument exception is an invalid-argument failure'
Assert-That -Condition ([object]::ReferenceEquals($typed.Exception, $converted.Exception)) `
    -Message 'The record keeps the original exception'
Assert-Equal -Expected $null -Actual $converted.TargetObject -Message 'and has no target when the original had none'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a string thrown by a script, which PowerShell reports with the
# string as the ID and as the target
$thrown = try { throw 'boom' } catch { $_ }

# Act
$converted = Get-CommandError -ErrorRecord $thrown

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A thrown string gets the runtime exception''s name as its ID, not its text'
Assert-Equal -Expected 'InvalidOperation' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and the general invalid-operation category'
Assert-Equal -Expected 'boom' -Actual $converted.TargetObject -Message 'and keeps the target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet, which already has a real ID and category
$missing = Join-Path ([IO.Path]::GetTempPath()) "no-such-$([Guid]::NewGuid())"
$native = try { Get-Item -LiteralPath $missing -ErrorAction Stop } catch { $_ }

# Act
$converted = Get-CommandError -ErrorRecord $native

# Assert
Assert-Equal -Expected 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand' `
    -Actual $converted.FullyQualifiedErrorId -Message 'A built-in cmdlet''s error keeps its ID'
Assert-Equal -Expected 'ObjectNotFound' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and its category'
Assert-Equal -Expected $native.TargetObject -Actual $converted.TargetObject -Message 'and its target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a real ID with no category
$record = New-FailureRecord -Exception ([ArgumentException]::new('x')) -ErrorId 'Custom.Failure' -Target 'the target'

# Act
$converted = Get-CommandError -ErrorRecord $record

# Assert
Assert-Equal -Expected 'Custom.Failure' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A real ID is kept when only the category is missing'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and the category is worked out from the exception'
Assert-Equal -Expected 'the target' -Actual $converted.TargetObject -Message 'and the target is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a real category, which names a kind of failure already
$record = New-FailureRecord -Exception ([ArgumentException]::new('x')) -Category ReadError

# Act
$converted = Get-CommandError -ErrorRecord $record

# Assert
Assert-Equal -Expected 'ReadError' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'A category other than not-specified or operation-stopped is kept, whatever the exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID that holds white space, which no caller can match on
$record = New-FailureRecord -Exception ([InvalidOperationException]::new('x')) -ErrorId 'two words'

# Act
$converted = Get-CommandError -ErrorRecord $record

# Assert
Assert-Equal -Expected 'InvalidOperationException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An ID with white space is replaced by the exception type''s name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one exception per category the converter names
$cases = @(
    @{ Exception = [ArgumentNullException]::new('p'); Expected = 'InvalidArgument' }
    @{ Exception = [IO.FileNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [IO.DirectoryNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.Management.Automation.ItemNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [UnauthorizedAccessException]::new('x'); Expected = 'PermissionDenied' }
    @{ Exception = [TimeoutException]::new('x'); Expected = 'OperationTimeout' }
    @{ Exception = [InvalidOperationException]::new('x'); Expected = 'InvalidOperation' }
)

# Act
$categories = foreach ($case in $cases) {
    $record = New-FailureRecord -Exception $case.Exception
    "$((Get-CommandError -ErrorRecord $record).CategoryInfo.Category)"
}

# Assert
Assert-Equal -Expected @($cases.ForEach('Expected')) -Actual @($categories) `
    -Message 'Each kind of exception gets its category, and any other is an invalid operation'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same exceptions, from a record that says it was stopped
$stopped = foreach ($case in $cases) {
    New-FailureRecord -Exception $case.Exception -Category OperationStopped
}

# Act
$categories = foreach ($record in $stopped) {
    "$((Get-CommandError -ErrorRecord $record).CategoryInfo.Category)"
}

# Assert
Assert-Equal -Expected @($cases.ForEach('Expected')) -Actual @($categories) `
    -Message 'An operation-stopped record is sorted the same way as a not-specified one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a target that is an object, not text
$target = [PSCustomObject]@{ Name = 'item' }
$record = New-FailureRecord -Exception ([InvalidOperationException]::new('x')) -Target $target

# Act
$converted = Get-CommandError -ErrorRecord $record

# Assert
Assert-That -Condition ([object]::ReferenceEquals($target, $converted.TargetObject)) `
    -Message 'The target is the very object the failure named'

exit (Complete-TestRun)
