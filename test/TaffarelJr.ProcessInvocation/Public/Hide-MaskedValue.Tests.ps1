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

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values to hide, and the text each leaves
$hidden = @(
    @{
        Text = 'git config password SENTINEL_SECRET_123'
        Mask = 'SENTINEL_SECRET_123'
        Expected = 'git config password ***'
        Message = 'A value is replaced by ***'
    }
    @{
        Text = 'a SENTINEL_SECRET_123 b SENTINEL_SECRET_123 c'
        Mask = 'SENTINEL_SECRET_123'
        Expected = 'a *** b *** c'
        Message = 'and so is every occurrence of it'
    }
    @{
        Text = 'SENTINEL_SECRET_123SENTINEL_SECRET_123'
        Mask = 'SENTINEL_SECRET_123'
        Expected = '******'
        Message = 'including two that touch'
    }
    @{
        Text = 'user=alpha-token-1 pass=beta-token-2'
        Mask = @('alpha-token-1', 'beta-token-2')
        Expected = 'user=*** pass=***'
        Message = 'Each of several values is replaced'
    }
    @{
        Text = 'x SENTINEL_SECRET_123 y'
        Mask = @('SENTINEL_SECRET_123', $null, '', 'SENTINEL_SECRET_123')
        Expected = 'x *** y'
        Message = 'A $null entry, an empty one, and a repeated one change nothing'
    }
    @{
        Text = 'a.b*c[d]e (f) $g ^h \i |j'
        Mask = @('b*c[d]', '(f) $g', '^h \i |j')
        Expected = 'a.***e *** ***'
        Message = 'A value is matched as the text it is, not as a pattern'
    }
    @{
        Text = 'cost: $1 SENTINEL$1_SECRET'
        Mask = 'SENTINEL$1_SECRET'
        Expected = 'cost: $1 ***'
        Message = 'and a $ in a value, or in the text, is not read as a group reference'
    }
    @{
        Text = "first SENTINEL_SECRET_123`nsecond SENTINEL_SECRET_123"
        Mask = 'SENTINEL_SECRET_123'
        Expected = "first ***`nsecond ***"
        Message = 'A value on every line of a text is replaced, and the line break is kept'
    }
    @{
        Text = 'two words here'
        Mask = 'two words'
        Expected = '*** here'
        Message = 'A value holding a space is replaced as a whole'
    }
)

# Act / Assert
foreach ($case in $hidden) {
    Assert-Equal -Expected $case.Expected -Actual (Hide-MaskedValue -Text $case.Text -Mask $case.Mask) `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that must be left alone, and text that does not hold them
$kept = @(
    @{
        Text = 'password is Hunter2Hunter2'
        Mask = 'hunter2hunter2'
        Message = 'The match is case-sensitive: another casing is another value'
    }
    @{
        Text = 'abc and abcd and ab'
        Mask = 'abc'
        Message = 'A value of three characters is ignored: hiding it would garble the text'
    }
    @{
        Text = 'a b c'
        Mask = @('a', 'b', '')
        Message = 'and so are shorter ones, whatever they are'
    }
    @{
        Text = 'nothing secret here'
        Mask = 'SENTINEL_SECRET_123'
        Message = 'Text that does not hold the value is kept'
    }
    @{
        Text = 'nothing secret here'
        Mask = $null
        Message = 'A $null list hides nothing'
    }
    @{
        Text = 'nothing secret here'
        Mask = @()
        Message = 'and so does an empty one'
    }
    @{
        Text = 'nothing secret here'
        Mask = @($null)
        Message = 'and so does one holding only $null'
    }
    @{
        Text = ''
        Mask = 'SENTINEL_SECRET_123'
        Message = 'Empty text stays empty'
    }
)

# Act / Assert
foreach ($case in $kept) {
    Assert-Equal -Expected $case.Text -Actual (Hide-MaskedValue -Text $case.Text -Mask $case.Mask) `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that holds another, and a text holding each of them
$short = 'SENTINEL_SECRET_123'
$long = 'SENTINEL_SECRET_123_LONGER'
$nestedText = "token=$long end"
$bothText = "$long and $short"

# Act
$nested = Hide-MaskedValue -Text $nestedText -Mask @($short, $long)
$reversed = Hide-MaskedValue -Text $nestedText -Mask @($long, $short)
$both = Hide-MaskedValue -Text $bothText -Mask @($short, $long)

# Assert
Assert-Equal -Expected 'token=*** end' -Actual $nested `
    -Message 'The longest value is hidden first, so one that holds another is hidden whole'
Assert-Equal -Expected 'token=*** end' -Actual $reversed -Message 'whatever order the values are given in'
Assert-Equal -Expected '*** and ***' -Actual $both -Message 'and each is hidden where it stands, the shorter one too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$lines = @('first SENTINEL_SECRET_123', 'second', '', 'third SENTINEL_SECRET_123 SENTINEL_SECRET_123')

# Act
$perLine = @($lines | Hide-MaskedValue -Mask 'SENTINEL_SECRET_123')

# Assert
Assert-Equal -Expected @('first ***', 'second', '', 'third *** ***') -Actual $perLine `
    -Message 'Lines piped in come back one for one, each with the value hidden, and an empty one stays'

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromNull = Hide-MaskedValue -Text $null -Mask 'SENTINEL_SECRET_123'
$byPosition = Hide-MaskedValue 'a SENTINEL_SECRET_123' 'SENTINEL_SECRET_123'

# Assert
Assert-Equal -Expected '' -Actual $fromNull -Message '$null text gives empty text'
Assert-Equal -Expected 'a ***' -Actual $byPosition `
    -Message 'and -Text and -Mask are the first two positional parameters'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - hiding what it returned
$once = Hide-MaskedValue -Text 'a SENTINEL_SECRET_123 b' -Mask 'SENTINEL_SECRET_123'
$twice = Hide-MaskedValue -Text $once -Mask 'SENTINEL_SECRET_123'

# Assert
Assert-Equal -Expected $once -Actual $twice -Message 'Hiding what it returns gives the same text back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a SecureString, which would be taken for its type name and hide nothing real
$secure = ConvertTo-SecureString -String 'SENTINEL_SECRET_123' -AsPlainText -Force

# Act / Assert
Assert-Throws -ScriptBlock { Hide-MaskedValue -Text 'a SENTINEL_SECRET_123 b' -Mask $secure } `
    -MessageLike '*-Mask takes plain text*SecureString*' `
    -Message 'A SecureString is refused, pointing at the plain text form'
Assert-Throws -ScriptBlock { Hide-MaskedValue -Text 'a b' -Mask @('SENTINEL_SECRET_123', $secure) } `
    -MessageLike '*-Mask takes plain text*SecureString*' `
    -Message 'also among other values'

exit (Complete-TestRun)
