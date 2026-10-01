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
$module = Get-Module TaffarelJr.ProcessInvocation

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$values = @('SENTINEL_SECRET_123', 'second', 42)

# Act
$list = @(& $module { param($v) ConvertTo-MaskList -Mask $v } $values)

# Assert
Assert-Equal -Expected @('SENTINEL_SECRET_123', 'second', '42') -Actual $list `
    -Message 'Each value comes back as a string, in order, one at a time'

#───────────────────────────────────────────────────────────────────────────────
# Act
$withNull = @(& $module { param($v) ConvertTo-MaskList -Mask $v } @('SENTINEL_SECRET_123', $null))

# Assert
Assert-Equal -Expected @('SENTINEL_SECRET_123', '') -Actual $withNull `
    -Message 'A $null entry becomes an empty one'

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromNull = @(& $module { ConvertTo-MaskList -Mask $null })
$fromEmpty = @(& $module { ConvertTo-MaskList -Mask @() })

# Assert
Assert-Equal -Expected 0 -Actual $fromNull.Count -Message 'A $null list gives nothing'
Assert-Equal -Expected 0 -Actual $fromEmpty.Count -Message 'and so does an empty one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$secure = ConvertTo-SecureString -String 'SENTINEL_SECRET_123' -AsPlainText -Force

# Act / Assert
Assert-Throws -ScriptBlock { & $module { param($v) ConvertTo-MaskList -Mask $v } $secure } `
    -MessageLike '-Mask takes plain text: a SecureString would hide only its type name. Pass the secret as a string.' `
    -Message 'A SecureString is refused, saying why and what to pass instead'
Assert-Throws -ScriptBlock { & $module { param($v) ConvertTo-MaskList -Mask $v } @('first', $secure) } `
    -MessageLike '-Mask takes plain text*' `
    -Message 'also when it is one of several values'

exit (Complete-TestRun)
