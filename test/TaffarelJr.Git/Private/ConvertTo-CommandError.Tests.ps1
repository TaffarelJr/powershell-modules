#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed exception, as a function's own validation raises it
$record = [System.Management.Automation.ErrorRecord]::new(
    [System.ArgumentException]::new('bad value'), 'ArgumentException', 'NotSpecified', 'the target')

# Act
$converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Get-GitBranch' } $record

# Assert
Assert-Equal -Expected 'System.Management.Automation.ErrorRecord' -Actual $converted.GetType().FullName `
    -Message 'An error record comes back'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $converted.Exception)) `
    -Message 'It keeps the failure''s own exception'
Assert-Equal -Expected 'bad value' -Actual $converted.Exception.Message -Message 'so the message is unchanged'
Assert-Equal -Expected 'ArgumentException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An error ID that was already given is kept'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'An argument exception without a category becomes InvalidArgument'
Assert-Equal -Expected 'the target' -Actual $converted.TargetObject -Message 'The target is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what a plain throw of a string leaves behind
$thrown = try {
    throw 'Committing failed: nothing to commit.'
}
catch {
    $_
}

# Act
$converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'New-GitCommit' } $thrown

# Assert
Assert-Equal -Expected 'RuntimeException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An ID that is only the message text becomes the exception''s type name'
Assert-Equal -Expected 'InvalidOperation' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'The OperationStopped category a throw leaves becomes InvalidOperation'
Assert-Equal -Expected 'Committing failed: nothing to commit.' -Actual $converted.Exception.Message `
    -Message 'The message is kept'
Assert-Equal -Expected 'Committing failed: nothing to commit.' -Actual $converted.TargetObject `
    -Message 'and so is the target a throw gave it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an error from a built-in cmdlet, which already has a real ID and category
$missing = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-file-$([guid]::NewGuid())"
$native = try {
    Get-Item -LiteralPath $missing -ErrorAction Stop
}
catch {
    $_
}

# Act
$converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Get-GitDirectory' } $native

# Assert
Assert-Equal -Expected $native.FullyQualifiedErrorId -Actual $converted.FullyQualifiedErrorId `
    -Message 'The ID of a built-in cmdlet''s error is kept'
Assert-Equal -Expected 'ObjectNotFound' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and so is its category'
Assert-Equal -Expected $native.TargetObject -Actual $converted.TargetObject -Message 'and its target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record that has a real ID and category, though its exception is a plain one
$labelled = [System.Management.Automation.ErrorRecord]::new(
    [System.InvalidOperationException]::new('refused'), 'RefusedByGit', 'PermissionDenied', 'repo')

# Act
$converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Push-GitCommit' } $labelled

# Assert
Assert-Equal -Expected 'RefusedByGit' -Actual $converted.FullyQualifiedErrorId -Message 'A real ID is kept'
Assert-Equal -Expected 'PermissionDenied' -Actual "$($converted.CategoryInfo.Category)" `
    -Message 'and a real category is kept, whatever the exception type'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID that is more than one word is no ID
$wordy = [System.Management.Automation.ErrorRecord]::new(
    [System.InvalidOperationException]::new('refused'), 'refused by the remote', 'InvalidOperation', $null)

# Act
$converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Push-GitCommit' } $wordy

# Assert
Assert-Equal -Expected 'InvalidOperationException' -Actual $converted.FullyQualifiedErrorId `
    -Message 'An ID with white space in it becomes the exception''s type name'
Assert-Equal -Expected $null -Actual $converted.TargetObject -Message 'A missing target stays missing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one exception for each category the converter picks
$rows = @(
    @{ Exception = [System.ArgumentException]::new('x'); Expected = 'InvalidArgument' }
    @{ Exception = [System.ArgumentNullException]::new('x'); Expected = 'InvalidArgument' }
    @{ Exception = [System.Management.Automation.ItemNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.IO.FileNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.IO.DirectoryNotFoundException]::new('x'); Expected = 'ObjectNotFound' }
    @{ Exception = [System.UnauthorizedAccessException]::new('x'); Expected = 'PermissionDenied' }
    @{ Exception = [System.TimeoutException]::new('x'); Expected = 'OperationTimeout' }
    @{ Exception = [System.InvalidOperationException]::new('x'); Expected = 'InvalidOperation' }
    @{ Exception = [System.Exception]::new('x'); Expected = 'InvalidOperation' }
)

# Act / Assert
foreach ($row in $rows) {
    $typeName = $row.Exception.GetType().Name
    foreach ($start in 'NotSpecified', 'OperationStopped') {
        $given = [System.Management.Automation.ErrorRecord]::new($row.Exception, 'Id', $start, $null)
        $converted = & $module { param($r) ConvertTo-CommandError -ErrorRecord $r -Command 'Get-GitTag' } $given
        Assert-Equal -Expected $row.Expected -Actual "$($converted.CategoryInfo.Category)" `
            -Message "$typeName with the category $start becomes $($row.Expected)"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { & $module { ConvertTo-CommandError -ErrorRecord $null -Command 'Get-GitTag' } } `
    -MessageLike '*ErrorRecord*' -Message 'A call with no error record is refused'

exit (Complete-TestRun)
