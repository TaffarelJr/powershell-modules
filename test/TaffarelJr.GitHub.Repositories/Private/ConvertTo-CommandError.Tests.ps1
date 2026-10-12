#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') `
    -Force `
    -PassThru

$convert = {
    param([Management.Automation.ErrorRecord]$Record)

    ConvertTo-CommandError -ErrorRecord $Record -Command 'Test-Command'
}
$catch = {
    param([scriptblock]$Block)

    try {
        & $Block
    }
    catch {
        return $_
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a typed ArgumentException, which a bare throw leaves with no ID and no category to act on
$record = & $catch { throw [ArgumentException]::new('bad value') }

# Act
$result = & $module $convert $record

# Assert
Assert-Equal -Expected 'InvalidArgument' -Actual $result.CategoryInfo.Category.ToString() `
    -Message 'An ArgumentException is an invalid argument'
Assert-Equal -Expected 'ArgumentException' -Actual $result.FullyQualifiedErrorId `
    -Message 'and its ID names the kind of failure, not its message'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $result.Exception)) `
    -Message 'The failure keeps its own exception'
Assert-Equal -Expected 'bad value' -Actual $result.Exception.Message -Message 'and its message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a thrown string, whose ID is its own text
$record = & $catch { throw 'plain text' }

# Act
$result = & $module $convert $record

# Assert
Assert-Equal -Expected 'InvalidOperation' -Actual $result.CategoryInfo.Category.ToString() `
    -Message 'A thrown string is an invalid operation'
Assert-Equal -Expected 'RuntimeException' -Actual $result.FullyQualifiedErrorId `
    -Message 'and its ID is the exception type, not the message text it carried'
Assert-Equal -Expected 'plain text' -Actual $result.Exception.Message -Message 'The message is unchanged'
Assert-Equal -Expected 'plain text' -Actual $result.TargetObject -Message 'and so is the target the throw recorded'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure that already has a real ID, category, and target, from a built-in cmdlet
$missing = Join-Path ([IO.Path]::GetTempPath()) "missing-$([Guid]::NewGuid())"
$record = & $catch { Get-Item -LiteralPath $missing -ErrorAction Stop }

# Act
$result = & $module $convert $record

# Assert
Assert-Equal -Expected 'PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand' `
    -Actual $result.FullyQualifiedErrorId `
    -Message 'An error from a built-in cmdlet keeps its ID'
Assert-Equal -Expected 'ObjectNotFound' -Actual $result.CategoryInfo.Category.ToString() `
    -Message 'and its category'
Assert-Equal -Expected $missing -Actual $result.TargetObject -Message 'and its target'
Assert-That -Condition ([object]::ReferenceEquals($record.Exception, $result.Exception)) `
    -Message 'and its exception'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a record built with its own ID, category, and target
$target = [PSCustomObject]@{ Name = 'the target' }
$built = [Management.Automation.ErrorRecord]::new(
    [InvalidOperationException]::new('built'),
    'My.Specific.Id',
    [Management.Automation.ErrorCategory]::ResourceUnavailable,
    $target)

# Act
$result = & $module $convert $built

# Assert
Assert-Equal -Expected 'My.Specific.Id' -Actual $result.FullyQualifiedErrorId -Message 'A real ID is kept'
Assert-Equal -Expected 'ResourceUnavailable' -Actual $result.CategoryInfo.Category.ToString() `
    -Message 'and so is a real category, whatever the exception type'
Assert-That -Condition ([object]::ReferenceEquals($target, $result.TargetObject)) -Message 'and the target object'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ID that is only the message, and one that is a sentence, on records with a real category
$cases = @(
    @{
        Id        = 'the message'
        Text      = 'the message'
        Statement = 'An ID equal to the message is replaced by the exception type'
    }
    @{
        Id        = 'two words'
        Text      = 'something else'
        Statement = 'An ID holding a space is replaced by the exception type'
    }
)

# Act / Assert
foreach ($case in $cases) {
    $built = [Management.Automation.ErrorRecord]::new(
        [Exception]::new($case.Text),
        $case.Id,
        [Management.Automation.ErrorCategory]::ResourceUnavailable,
        $null)

    $result = & $module $convert $built

    Assert-Equal -Expected 'Exception' -Actual $result.FullyQualifiedErrorId -Message $case.Statement
    Assert-Equal -Expected 'ResourceUnavailable' -Actual $result.CategoryInfo.Category.ToString() `
        -Message "$($case.Statement), and a real category stays"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one exception type per category, on a record that says nothing and on one that only says it stopped
$categories = @(
    @{ Exception = [ArgumentException]::new('x'); Expected = 'InvalidArgument'; Case = 'ArgumentException' }
    @{ Exception = [ArgumentNullException]::new('x'); Expected = 'InvalidArgument'; Case = 'ArgumentNullException' }
    @{
        Exception = [Management.Automation.ItemNotFoundException]::new('x')
        Expected  = 'ObjectNotFound'
        Case      = 'ItemNotFoundException'
    }
    @{ Exception = [IO.FileNotFoundException]::new('x'); Expected = 'ObjectNotFound'; Case = 'FileNotFoundException' }
    @{
        Exception = [IO.DirectoryNotFoundException]::new('x')
        Expected  = 'ObjectNotFound'
        Case      = 'DirectoryNotFoundException'
    }
    @{
        Exception = [UnauthorizedAccessException]::new('x')
        Expected  = 'PermissionDenied'
        Case      = 'UnauthorizedAccessException'
    }
    @{ Exception = [TimeoutException]::new('x'); Expected = 'OperationTimeout'; Case = 'TimeoutException' }
    @{
        Exception = [InvalidOperationException]::new('x')
        Expected  = 'InvalidOperation'
        Case      = 'InvalidOperationException'
    }
    @{ Exception = [Exception]::new('x'); Expected = 'InvalidOperation'; Case = 'a plain Exception' }
)

# Act / Assert
foreach ($case in $categories) {
    foreach ($said in 'NotSpecified', 'OperationStopped') {
        $built = [Management.Automation.ErrorRecord]::new($case.Exception, 'Some.Id', $said, $null)

        $result = & $module $convert $built

        Assert-Equal -Expected $case.Expected -Actual $result.CategoryInfo.Category.ToString() `
            -Message "$($case.Case) is $($case.Expected), from a record saying $said"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the target of a failure that had one
$target = [PSCustomObject]@{ Name = 'the failing thing' }
$built = [Management.Automation.ErrorRecord]::new(
    [ArgumentException]::new('bad'),
    'Some.Id',
    [Management.Automation.ErrorCategory]::NotSpecified,
    $target)

# Act
$result = & $module $convert $built

# Assert
Assert-That -Condition ([object]::ReferenceEquals($target, $result.TargetObject)) `
    -Message 'The failing object stays the error''s target, so a caller can tell what was being worked on'
Assert-Equal -Expected 'InvalidArgument' -Actual $result.CategoryInfo.Category.ToString() `
    -Message 'while an unspecified category is still worked out from the exception'

exit (Complete-TestRun)
