#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what a plain throw of text leaves
$thrown = & { try { throw 'plain message' } catch { $_ } }

# Act
$converted = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $thrown

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A throw of text, whose ID is its own message, gets the exception type as its ID'
Assert-Equal -Expected 'InvalidOperation' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and the category a caller can act on'
Assert-Equal -Expected 'plain message' -Actual $converted.TargetObject -Message 'and keeps its target'
Assert-Equal -Expected $thrown.Exception -Actual $converted.Exception -Message 'and its own exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what a typed throw leaves
$thrown = & { try { throw [System.ArgumentException]::new('typed message') } catch { $_ } }

# Act
$converted = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $thrown

# Assert
Assert-Equal -Expected 'ArgumentException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'A typed throw gets its exception type as its ID'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and InvalidArgument as its category'
Assert-Equal -Expected $thrown.Exception -Actual $converted.Exception -Message 'and keeps its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error a built-in cmdlet raised, which has a real ID and category already
$missing = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-folder-$([guid]::NewGuid())"
Get-Item -LiteralPath $missing -ErrorAction SilentlyContinue -ErrorVariable native
$nativeRecord = $native[0]

# Act
$converted = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $nativeRecord

# Assert
Assert-Equal -Expected $nativeRecord.FullyQualifiedErrorId -Actual $converted.FullyQualifiedErrorId `
    -Message 'A built-in cmdlet''s error keeps its ID'
Assert-Equal -Expected 'ObjectNotFound' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and its category'
Assert-Equal -Expected $nativeRecord.TargetObject -Actual $converted.TargetObject -Message 'and its target'
Assert-Equal -Expected $nativeRecord.Exception -Actual $converted.Exception -Message 'and its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record that names its own ID and category
$target = [PSCustomObject]@{ Name = 'the target' }
$record = [System.Management.Automation.ErrorRecord]::new(
    [System.IO.IOException]::new('disk is full'),
    'DiskFull',
    [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
    $target)

# Act
$converted = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $record

# Assert
Assert-Equal -Expected 'DiskFull' -Actual $converted.FullyQualifiedErrorId -Message 'A real ID stays'
Assert-Equal -Expected 'ResourceUnavailable' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and a real category stays, whatever the exception is'
Assert-Equal -Expected $target -Actual $converted.TargetObject -Message 'and the target is the same object'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID with a space in it, an ID that is the message, and one that differs from it only in casing
$spaced = [System.Management.Automation.ErrorRecord]::new(
    [System.InvalidOperationException]::new('wrong'),
    'two words',
    [System.Management.Automation.ErrorCategory]::NotSpecified,
    $null)
$sameWord = [System.Management.Automation.ErrorRecord]::new(
    [System.InvalidOperationException]::new('oneword'),
    'oneword',
    [System.Management.Automation.ErrorCategory]::OperationStopped,
    $null)
$otherCase = [System.Management.Automation.ErrorRecord]::new(
    [System.InvalidOperationException]::new('Oneword'),
    'oneword',
    [System.Management.Automation.ErrorCategory]::OperationStopped,
    $null)

# Act
$fromSpaced = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $spaced
$fromSameWord = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $sameWord
$fromOtherCase = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $otherCase

# Assert
Assert-Equal -Expected 'InvalidOperationException' -Actual $fromSpaced.FullyQualifiedErrorId `
    -Message 'An ID with a space in it is replaced by the exception type'
Assert-Equal -Expected 'InvalidOperationException' -Actual $fromSameWord.FullyQualifiedErrorId `
    -Message 'and so is an ID that is the message'
Assert-Equal -Expected 'oneword' -Actual $fromOtherCase.FullyQualifiedErrorId `
    -Message 'but an ID that differs from the message only in casing is a real one'
Assert-Equal -Expected $null -Actual $fromSpaced.TargetObject -Message 'A missing target stays missing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each kind of exception, with the category a bare throw leaves
$kinds = @(
    @{
        Exception = [System.ArgumentException]::new('bad value')
        Id        = 'ArgumentException'
        Category  = 'InvalidArgument'
        Message   = 'An ArgumentException is an invalid argument'
    }
    @{
        Exception = [System.ArgumentNullException]::new('value')
        Id        = 'ArgumentNullException'
        Category  = 'InvalidArgument'
        Message   = 'and so is one derived from it'
    }
    @{
        Exception = [System.Management.Automation.ItemNotFoundException]::new('no such item')
        Id        = 'ItemNotFoundException'
        Category  = 'ObjectNotFound'
        Message   = 'An item that is not found is an object not found'
    }
    @{
        Exception = [System.IO.FileNotFoundException]::new('no such file')
        Id        = 'FileNotFoundException'
        Category  = 'ObjectNotFound'
        Message   = 'and so is a file'
    }
    @{
        Exception = [System.IO.DirectoryNotFoundException]::new('no such folder')
        Id        = 'DirectoryNotFoundException'
        Category  = 'ObjectNotFound'
        Message   = 'and a folder'
    }
    @{
        Exception = [System.UnauthorizedAccessException]::new('not allowed')
        Id        = 'UnauthorizedAccessException'
        Category  = 'PermissionDenied'
        Message   = 'An unauthorized access is a permission denied'
    }
    @{
        Exception = [System.TimeoutException]::new('too slow')
        Id        = 'TimeoutException'
        Category  = 'OperationTimeout'
        Message   = 'A timeout is an operation timeout'
    }
    @{
        Exception = [System.InvalidOperationException]::new('not now')
        Id        = 'InvalidOperationException'
        Category  = 'InvalidOperation'
        Message   = 'An invalid operation is an invalid operation'
    }
    @{
        Exception = [System.IO.IOException]::new('read failed')
        Id        = 'IOException'
        Category  = 'InvalidOperation'
        Message   = 'and any other exception falls back to the same'
    }
)
foreach ($kind in $kinds) {
    $record = [System.Management.Automation.ErrorRecord]::new(
        $kind.Exception,
        $kind.Exception.Message,
        [System.Management.Automation.ErrorCategory]::OperationStopped,
        'the target')

    # Act
    $converted = & $module { ConvertTo-CommandError -ErrorRecord $args[0] -Command 'Get-Thing' } $record

    # Assert
    Assert-Equal -Expected $kind.Category -Actual "$($converted.CategoryInfo.Category)" -Message $kind.Message
    Assert-Equal -Expected $kind.Id -Actual $converted.FullyQualifiedErrorId `
        -Message "$($kind.Message): the ID names it"
}

exit (Complete-TestRun)
