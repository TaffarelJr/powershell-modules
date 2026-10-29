#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') `
    -Force -PassThru

$convert = {
    param([System.Management.Automation.ErrorRecord]$Record)
    ConvertTo-CommandError -ErrorRecord $Record -Command 'Get-Thing'
}

# The record PowerShell makes of a failure: what a catch block's $_ holds.
$catch = {
    param([scriptblock]$Failing)
    try {
        & $Failing
    }
    catch {
        $_
    }
}

# A record that has an ID but no category, as a caller's own code might make one.
$uncategorized = {
    param([Exception]$Exception, [string]$Id, $Target)
    $none = [System.Management.Automation.ErrorCategory]::NotSpecified
    [System.Management.Automation.ErrorRecord]::new($Exception, $Id, $none, $Target)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed exception thrown by the caller's own code
$exception = [System.ArgumentException]::new('the value is wrong')
$record = & $catch { throw $exception }

# Act
$converted = & $module $convert $record

# Assert
Assert-That -Condition ([object]::ReferenceEquals($exception, $converted.Exception)) `
    -Message 'The failure keeps its own exception, so its type and message reach the caller'
Assert-Equal -Expected 'ArgumentException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'The error ID names the kind of failure, not the message'
Assert-Equal -Expected 'InvalidArgument' -Actual $converted.CategoryInfo.Category.ToString() `
    -Message 'An argument exception reads as an invalid argument'
Assert-Equal -Expected $null -Actual $converted.TargetObject -Message 'and a target the throw never had stays empty'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a string thrown by the caller's own code
$record = & $catch { throw 'Something went wrong with o/r.' }

# Act
$converted = & $module $convert $record

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A thrown string gets the error ID of its exception type, not its own text'
Assert-Equal -Expected 'InvalidOperation' -Actual $converted.CategoryInfo.Category.ToString() `
    -Message 'and the category of an operation that failed'
Assert-Equal -Expected 'Something went wrong with o/r.' -Actual $converted.Exception.Message `
    -Message 'with its message unchanged'
Assert-Equal -Expected 'Something went wrong with o/r.' -Actual $converted.TargetObject `
    -Message 'and the target PowerShell gave it'
Assert-That -Condition ($converted -is [System.Management.Automation.ErrorRecord]) `
    -Message 'The result is an error record'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet, which already has a real ID and category
$missing = Join-Path ([System.IO.Path]::GetTempPath()) "gh-account-missing-$([Guid]::NewGuid())"
$record = & $catch { Get-Item -LiteralPath $missing -ErrorAction Stop }

# Act
$converted = & $module $convert $record

# Assert
Assert-Equal -Expected $record.FullyQualifiedErrorId -Actual $converted.FullyQualifiedErrorId `
    -Message 'A built-in cmdlet''s error ID is kept'
Assert-Equal -Expected 'ObjectNotFound' -Actual $converted.CategoryInfo.Category.ToString() -Message 'and its category'
Assert-Equal -Expected $missing -Actual $converted.TargetObject -Message 'and its target'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $converted.Exception)) `
    -Message 'and its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record the caller already gave an ID, a category, and a target
$exception = [System.InvalidOperationException]::new('the gist is locked')
$target = [PSCustomObject]@{ Id = 'abc' }
$record = [System.Management.Automation.ErrorRecord]::new(
    $exception, 'Gist.Locked', [System.Management.Automation.ErrorCategory]::ResourceUnavailable, $target)

# Act
$converted = & $module $convert $record

# Assert
Assert-Equal -Expected 'Gist.Locked' -Actual $converted.FullyQualifiedErrorId -Message 'A real error ID is kept'
Assert-Equal -Expected 'ResourceUnavailable' -Actual $converted.CategoryInfo.Category.ToString() `
    -Message 'and a real category'
Assert-That -Condition ([object]::ReferenceEquals($target, $converted.TargetObject)) -Message 'and the very target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each kind of exception and the category a caller can act on, from a record with none
$cases = @(
    @{ Exception = [System.ArgumentException]::new('m'); Expected = 'InvalidArgument'; Name = 'ArgumentException' }
    @{
        Exception = [System.ArgumentOutOfRangeException]::new('p', 'm')
        Expected = 'InvalidArgument'
        Name = 'An exception derived from ArgumentException'
    }
    @{
        Exception = [System.Management.Automation.ItemNotFoundException]::new('m')
        Expected = 'ObjectNotFound'
        Name = 'ItemNotFoundException'
    }
    @{
        Exception = [System.IO.FileNotFoundException]::new('m')
        Expected = 'ObjectNotFound'
        Name = 'FileNotFoundException'
    }
    @{
        Exception = [System.IO.DirectoryNotFoundException]::new('m')
        Expected = 'ObjectNotFound'
        Name = 'DirectoryNotFoundException'
    }
    @{
        Exception = [System.UnauthorizedAccessException]::new('m')
        Expected = 'PermissionDenied'
        Name = 'UnauthorizedAccessException'
    }
    @{ Exception = [System.TimeoutException]::new('m'); Expected = 'OperationTimeout'; Name = 'TimeoutException' }
    @{
        Exception = [System.InvalidOperationException]::new('m')
        Expected = 'InvalidOperation'
        Name = 'InvalidOperationException'
    }
    @{
        Exception = [System.IO.InvalidDataException]::new('m')
        Expected = 'InvalidOperation'
        Name = 'Any other exception'
    }
)

# Act / Assert
foreach ($case in $cases) {
    $converted = & $module $convert (& $uncategorized $case.Exception 'SomeId' $null)
    Assert-Equal -Expected $case.Expected -Actual $converted.CategoryInfo.Category.ToString() `
        -Message "$($case.Name) is category $($case.Expected)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a thrown timeout, whose record PowerShell categorizes as a stopped operation
$record = & $catch { throw [System.TimeoutException]::new('Waited too long.') }

# Act
$converted = & $module $convert $record

# Assert
Assert-Equal -Expected 'OperationTimeout' -Actual $converted.CategoryInfo.Category.ToString() `
    -Message 'A stopped operation is re-categorized by what was thrown'
Assert-Equal -Expected 'TimeoutException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'and gets the type''s name as its ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - IDs that say nothing: the message itself, and text with spaces
$sentence = [System.InvalidOperationException]::new('the same sentence')
$cases = @(
    @{ Id = 'the same sentence'; Exception = $sentence; Name = 'An ID that repeats the message' }
    @{ Id = 'two words'; Exception = $sentence; Name = 'An ID with a space in it' }
)

# Act / Assert
foreach ($case in $cases) {
    $converted = & $module $convert (& $uncategorized $case.Exception $case.Id $null)
    Assert-Equal -Expected 'InvalidOperationException' -Actual $converted.FullyQualifiedErrorId `
        -Message "$($case.Name) is replaced by the name of the exception's type"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a target that is an object, and an ID that is a real word
$target = [PSCustomObject]@{ Repository = 'o/r' }
$record = & $uncategorized ([System.ArgumentException]::new('m')) 'BadRepository' $target

# Act
$converted = & $module $convert $record

# Assert
Assert-That -Condition ([object]::ReferenceEquals($target, $converted.TargetObject)) `
    -Message 'The target is the very object'
Assert-Equal -Expected 'BadRepository' -Actual $converted.FullyQualifiedErrorId -Message 'and a one-word ID is kept'

exit (Complete-TestRun)
