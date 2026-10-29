#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A test builds a fake secret from a literal.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @(Get-WorkflowCommand { Hide-GitHubActionsValue 's3cr3t-token' })

# Assert
Assert-Equal -Expected @('::add-mask::s3cr3t-token') -Actual $lines `
    -Message 'One line is written: the add-mask command, with the value as its data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act
$piped = @(Get-WorkflowCommand { 'secret-one', 'secret-two' | Hide-GitHubActionsValue })

# Assert
Assert-Equal -Expected @('::add-mask::secret-one', '::add-mask::secret-two') -Actual $piped `
    -Message 'Each piped value is masked with a command of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act - a value of several lines, as a private key is, with a blank one
$key = @(Get-WorkflowCommand { Hide-GitHubActionsValue "-----BEGIN KEY-----`nabc123`r`n   `n100%-----END KEY-----" })

# Assert
Assert-Equal -Expected @('::add-mask::-----BEGIN KEY-----%0Aabc123%0D%0A   %0A100%25-----END KEY-----') -Actual $key `
    -Message 'A value of several lines is sent whole, escaped, for the runner to mask whole and line by line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$secure = ConvertTo-SecureString -String 'p@ssw0rd-real' -AsPlainText -Force

# Act
$fromSecure = @(Get-WorkflowCommand { Hide-GitHubActionsValue $secure })

# Assert
Assert-Equal -Expected @('::add-mask::p@ssw0rd-real') -Actual $fromSecure `
    -Message 'A SecureString masks the secret it holds, not its type name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$blanks = @{
    Empty  = ''
    Spaces = '   '
    Null   = $null
}

# Act
$ignored = @(Get-WorkflowCommand {
        Hide-GitHubActionsValue $blanks.Empty
        Hide-GitHubActionsValue $blanks.Spaces
        Hide-GitHubActionsValue $blanks.Null
        Hide-GitHubActionsValue ([securestring]::new())
    })

# Assert
Assert-Equal -Expected 0 -Actual $ignored.Count `
    -Message 'An empty, blank, or $null value, or an empty SecureString, is ignored, so an unset optional secret can be passed'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    [PSCustomObject]@{ Value = 'tok123456' } | Hide-GitHubActionsValue
} -MessageLike 'A value of type PSCustomObject cannot be masked*give the secret''s text, as a string or a SecureString.' `
    -Message 'Any other object is refused, as its text would not be the secret'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Hide-GitHubActionsValue 42 } -MessageLike 'A value of type Int32 cannot be masked*' `
    -Message 'as is a number'

exit (Complete-TestRun)
