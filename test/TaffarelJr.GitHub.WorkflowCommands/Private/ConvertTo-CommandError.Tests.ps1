#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

$catchRecord = {
    param([scriptblock]$Block)

    try {
        & $Block
    }
    catch {
        $_
    }
}
$convert = {
    param($Record)

    & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Test-Command' } $Record
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed exception thrown as it is
$record = & $catchRecord { throw [System.ArgumentException]::new('bad value') }

# Act
$converted = & $convert $record

# Assert
Assert-That -Condition ($converted -is [System.Management.Automation.ErrorRecord]) `
    -Message 'An error record comes back'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $converted.Exception)) `
    -Message 'It keeps the failure''s own exception'
Assert-Equal -Expected 'InvalidArgument' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'An argument exception becomes InvalidArgument'
Assert-Equal -Expected 'ArgumentException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'and its ID, which was the message text, becomes the exception''s type name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a string thrown, which PowerShell wraps in a RuntimeException and uses as its own ID and target
$record = & $catchRecord { throw 'plain message' }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A thrown string gets the type name as its ID, not its text'
Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'and the InvalidOperation category'
Assert-Equal -Expected 'plain message' -Actual $converted.TargetObject -Message 'and keeps its target'
Assert-Equal -Expected 'plain message' -Actual $converted.Exception.Message -Message 'and its message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the categories a caller can act on, one exception type each
$missingFolder = Join-Path ([System.IO.Path]::GetTempPath()) "wfc-missing-$([guid]::NewGuid())"
$cases = @(
    @{ Exception = [System.ArgumentNullException]::new('p'); Expected = 'InvalidArgument' }
    @{ Exception = [System.IO.FileNotFoundException]::new('no file'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.IO.DirectoryNotFoundException]::new('no folder'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.UnauthorizedAccessException]::new('denied'); Expected = 'PermissionDenied' }
    @{ Exception = [System.TimeoutException]::new('slow'); Expected = 'OperationTimeout' }
    @{ Exception = [System.InvalidOperationException]::new('nope'); Expected = 'InvalidOperation' }
    @{ Exception = [System.IO.IOException]::new('disk'); Expected = 'InvalidOperation' }
    @{ Exception = [System.Exception]::new('anything'); Expected = 'InvalidOperation' }
)
# Act / Assert
foreach ($case in $cases) {
    $exception = $case.Exception
    $record = & $catchRecord { throw $exception }
    $converted = & $convert $record
    $typeName = $exception.GetType().Name
    Assert-Equal -Expected $case.Expected -Actual ([string]$converted.CategoryInfo.Category) `
        -Message "A $typeName is $($case.Expected)"
    Assert-Equal -Expected $typeName -Actual $converted.FullyQualifiedErrorId `
        -Message "and its ID is the type name $typeName"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an item-not-found exception that carries no category, as one raised by a provider can
$exception = [System.Management.Automation.ItemNotFoundException]::new('no item')
$original = [System.Management.Automation.ErrorRecord]::new($exception, 'no item', 'NotSpecified', $null)
$record = & $catchRecord { throw $original }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected 'ObjectNotFound' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'An item-not-found exception without a category is ObjectNotFound'
Assert-Equal -Expected 'ItemNotFoundException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'and its ID is the type name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet, which already has an ID, a category and a target
$record = & $catchRecord { Get-Item -LiteralPath $missingFolder -ErrorAction Stop }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected $record.FullyQualifiedErrorId -Actual $converted.FullyQualifiedErrorId `
    -Message 'A native error keeps its ID'
Assert-Equal -Expected 'ObjectNotFound' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'and its category'
Assert-Equal -Expected $missingFolder -Actual $converted.TargetObject -Message 'and its target'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $converted.Exception)) `
    -Message 'and its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record that was given a real ID, a category and a target
$original = [System.Management.Automation.ErrorRecord]::new(
    [System.Exception]::new('with target'), 'Custom.Id', 'ResourceUnavailable', 'THE TARGET')
$record = & $catchRecord { throw $original }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected 'Custom.Id' -Actual $converted.FullyQualifiedErrorId -Message 'A real ID is kept'
Assert-Equal -Expected 'ResourceUnavailable' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'and so is a real category'
Assert-Equal -Expected 'THE TARGET' -Actual $converted.TargetObject -Message 'and the target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a real ID with no category
$original = [System.Management.Automation.ErrorRecord]::new(
    [System.Exception]::new('msg'), 'Custom.Id', 'NotSpecified', 42)
$record = & $catchRecord { throw $original }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected 'Custom.Id' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A real ID is kept when the category is not specified'
Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'and the category is worked out from the exception'
Assert-Equal -Expected 42 -Actual $converted.TargetObject -Message 'and the target is the one it had'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID that is a sentence is no ID
$original = [System.Management.Automation.ErrorRecord]::new(
    [System.Exception]::new('msg'), 'has some spaces', 'ObjectNotFound', 'T')
$record = & $catchRecord { throw $original }

# Act
$converted = & $convert $record

# Assert
Assert-Equal -Expected 'Exception' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An ID with white space is replaced with the exception''s type name'
Assert-Equal -Expected 'ObjectNotFound' -Actual ([string]$converted.CategoryInfo.Category) `
    -Message 'and a real category is still kept'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { & $module { ConvertTo-CommandError -ErrorRecord $null -Command 'Test-Command' } } `
    -MessageLike '*ErrorRecord*' -Message 'Without a record, there is nothing to convert'

exit (Complete-TestRun)
