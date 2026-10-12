#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru

$capture = {
    param([scriptblock]$Block)

    try {
        & $Block
    }
    catch {
        $_
    }
}
$convert = {
    param([System.Management.Automation.ErrorRecord]$Record, [string]$Command = 'Test-Command')

    & $module {
        param($Record, $Command)
        ConvertTo-CommandError -ErrorRecord $Record -Command $Command
    } $Record $Command
}
$category = [System.Management.Automation.ErrorCategory]

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed ArgumentException
$record = & $capture { throw [System.ArgumentException]::new('bad value') }

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'ArgumentException' -Actual $result.FullyQualifiedErrorId `
    -Message 'A typed exception with no error ID of its own is named by its type'
Assert-Equal -Expected $category::InvalidArgument -Actual $result.CategoryInfo.Category `
    -Message 'and an ArgumentException is an invalid argument'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $result.Exception)) `
    -Message 'The exception itself is kept, not wrapped'
Assert-Equal -Expected 'bad value' -Actual $result.Exception.Message -Message 'with its message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a string thrown
$record = & $capture { throw 'plain message' }

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $result.FullyQualifiedErrorId `
    -Message 'A thrown string, whose ID is its own text, is named by the type of its exception'
Assert-Equal -Expected $category::InvalidOperation -Actual $result.CategoryInfo.Category `
    -Message 'and is an invalid operation, not an operation that was stopped'
Assert-Equal -Expected 'plain message' -Actual $result.Exception.Message -Message 'with the text as its message'
Assert-Equal -Expected 'plain message' -Actual $result.TargetObject -Message 'and the text as its target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet
$missing = Join-Path ([IO.Path]::GetTempPath()) "missing-$([Guid]::NewGuid())"
$record = & $capture { Get-Item -LiteralPath $missing -ErrorAction Stop }

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand' `
    -Actual $result.FullyQualifiedErrorId `
    -Message 'A built-in cmdlet''s error keeps its ID'
Assert-Equal -Expected $category::ObjectNotFound -Actual $result.CategoryInfo.Category -Message 'and its category'
Assert-Equal -Expected $missing -Actual $result.TargetObject -Message 'and its target'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $result.Exception)) `
    -Message 'and its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record that already has a real ID and category
$exception = [System.IO.IOException]::new('The disk is full.')
$record = [System.Management.Automation.ErrorRecord]::new($exception, 'Disk.Full', $category::ResourceUnavailable, 'D:')

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'Disk.Full' -Actual $result.FullyQualifiedErrorId -Message 'A real error ID is kept'
Assert-Equal -Expected $category::ResourceUnavailable -Actual $result.CategoryInfo.Category `
    -Message 'and a real category'
Assert-Equal -Expected 'D:' -Actual $result.TargetObject -Message 'and the target'
Assert-That -Condition ([object]::ReferenceEquals($exception, $result.Exception)) -Message 'and the exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each kind of exception, as a throw reports it, and the category it earns
$kinds = @(
    @{ Exception = [System.ArgumentException]::new('a'); Expected = $category::InvalidArgument }
    @{ Exception = [System.ArgumentNullException]::new('a'); Expected = $category::InvalidArgument }
    @{ Exception = [System.IO.FileNotFoundException]::new('a'); Expected = $category::ObjectNotFound }
    @{ Exception = [System.IO.DirectoryNotFoundException]::new('a'); Expected = $category::ObjectNotFound }
    @{ Exception = [System.UnauthorizedAccessException]::new('a'); Expected = $category::PermissionDenied }
    @{ Exception = [System.TimeoutException]::new('a'); Expected = $category::OperationTimeout }
    @{ Exception = [System.InvalidOperationException]::new('a'); Expected = $category::InvalidOperation }
    @{ Exception = [System.FormatException]::new('a'); Expected = $category::InvalidOperation }
)
foreach ($kind in $kinds) {
    $thrown = $kind.Exception
    $record = & $capture { throw $thrown }

    # Act
    $result = & $convert $record

    # Assert
    Assert-Equal -Expected $kind.Expected -Actual $result.CategoryInfo.Category `
        -Message "A thrown $($thrown.GetType().Name) is $($kind.Expected)"
    Assert-Equal -Expected $thrown.GetType().Name -Actual $result.FullyQualifiedErrorId `
        -Message "and its ID is $($thrown.GetType().Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ItemNotFoundException, which carries a record of its own when thrown, in a record that has none
$exception = [System.Management.Automation.ItemNotFoundException]::new('gone')
$record = [System.Management.Automation.ErrorRecord]::new($exception, 'Gone', $category::OperationStopped, $null)

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected $category::ObjectNotFound -Actual $result.CategoryInfo.Category `
    -Message 'An ItemNotFoundException is an object that was not found'
Assert-Equal -Expected 'Gone' -Actual $result.FullyQualifiedErrorId -Message 'and its real ID is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record whose category was never specified, but whose ID is real
$target = [PSCustomObject]@{ Name = 'the target' }
$exception = [System.ArgumentException]::new('bad')
$record = [System.Management.Automation.ErrorRecord]::new($exception, 'Real.Id', $category::NotSpecified, $target)

# Act
$result = & $convert $record

# Assert
Assert-Equal -Expected 'Real.Id' -Actual $result.FullyQualifiedErrorId `
    -Message 'A real ID is kept whatever the category was'
Assert-Equal -Expected $category::InvalidArgument -Actual $result.CategoryInfo.Category `
    -Message 'and an unspecified category is worked out from the exception'
Assert-That -Condition ([object]::ReferenceEquals($target, $result.TargetObject)) `
    -Message 'The target object itself is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - IDs that name nothing
$exception = [System.InvalidOperationException]::new('The same text')
$sameText = [System.Management.Automation.ErrorRecord]::new($exception, 'The same text', $category::NotSpecified, $null)
$spaced = [System.Management.Automation.ErrorRecord]::new($exception, 'has some spaces', $category::NotSpecified, $null)
$boom = [System.Exception]::new('boom')
$word = [System.Management.Automation.ErrorRecord]::new($boom, 'Boom', $category::NotSpecified, $null)

# Act
$fromSameText = & $convert $sameText
$fromSpaced = & $convert $spaced
$fromWord = & $convert $word

# Assert
Assert-Equal -Expected 'InvalidOperationException' -Actual $fromSameText.FullyQualifiedErrorId `
    -Message 'An ID equal to the message is replaced by the exception''s type'
Assert-Equal -Expected 'InvalidOperationException' -Actual $fromSpaced.FullyQualifiedErrorId `
    -Message 'and so is an ID with white space in it'
Assert-Equal -Expected 'Boom' -Actual $fromWord.FullyQualifiedErrorId `
    -Message 'but an ID that differs from the message only in case is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$record = & $capture { throw [System.TimeoutException]::new('too slow') }

# Act
$first = & $convert $record 'One-Command'
$second = & $convert $record 'Another-Command'

# Assert
Assert-Equal -Expected $first.FullyQualifiedErrorId -Actual $second.FullyQualifiedErrorId `
    -Message 'The command name given does not change the ID'
Assert-Equal -Expected $first.CategoryInfo.Category -Actual $second.CategoryInfo.Category `
    -Message 'or the category'
Assert-That -Condition ($first -is [System.Management.Automation.ErrorRecord]) -Message 'The result is an ErrorRecord'

exit (Complete-TestRun)
