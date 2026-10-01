#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Get-Module TaffarelJr.ProcessInvocation

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command and arguments made only of characters PowerShell leaves alone
$plain = & $module {
    Format-NativeCommandLine -Command 'git' -Arguments @('ls-files', '--others', 'C:\x\y.txt', '--limit=5')
}

# Assert
Assert-Equal -Expected 'git ls-files --others C:\x\y.txt --limit=5' -Actual $plain `
    -Message 'Words PowerShell reads as they are stay bare'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - arguments that are empty, spaced, or that PowerShell would act on
$quoted = & $module {
    Format-NativeCommandLine -Command 'git' -Arguments @('two words', '', "it's", 'a;b', '$x', '--%')
}

# Assert
Assert-Equal -Expected "git 'two words' '' 'it''s' 'a;b' '`$x' '--%'" -Actual $quoted `
    -Message 'Every other word is single-quoted, with a single quote doubled'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a typographic single quote, which PowerShell ends a quoted string on too
$typographic = & $module {
    Format-NativeCommandLine -Command 'git' -Arguments @("it$([char]0x2019)s")
}

# Assert
Assert-Equal -Expected "git 'it$([char]0x2019)$([char]0x2019)s'" -Actual $typographic `
    -Message 'A typographic single quote is doubled like the ASCII one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command whose own name needs quoting
$spaced = & $module {
    Format-NativeCommandLine -Command 'My Tool' -Arguments @('x')
}

# Assert
Assert-Equal -Expected "& 'My Tool' x" -Actual $spaced `
    -Message 'A quoted command is preceded by the call operator, so the line still runs it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - credentials in the command and in arguments, each word on its own
$hidden = & $module {
    Format-NativeCommandLine -Command 'git' -Arguments @(
        'clone', 'https://x-access-token:SENTINEL@h.example/o/r', 'me@example.com'
    )
}

# Assert
Assert-Equal -Expected "git clone 'https://***@h.example/o/r' me@example.com" -Actual $hidden `
    -Message 'The credential a URL carries is hidden in the word that holds it, and in no other'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a value to mask, as a word of its own and inside others
$masked = & $module {
    Format-NativeCommandLine -Command 'git' -Mask 'SENTINEL_SECRET_123' -Arguments @(
        'config', 'password', 'SENTINEL_SECRET_123', '--password=SENTINEL_SECRET_123', 'other'
    )
}

# Assert
Assert-Equal -Expected "git config password '***' '--password=***' other" -Actual $masked `
    -Message 'Each value is hidden in the word that holds it, before the word is quoted'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a value that is quoted in the line, and one that holds a single quote
$quote = & $module {
    Format-NativeCommandLine -Command 'git' -Mask "it's SENTINEL" -Arguments @("it's SENTINEL", 'x')
}

# Assert
Assert-Equal -Expected "git '***' x" -Actual $quote `
    -Message 'A value holding spaces and a single quote is matched as it was given, not as it is quoted'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a value that is a credential in a URL as well
$both = & $module {
    Format-NativeCommandLine -Command 'git' -Mask 'p@ss_SENTINEL' -Arguments @(
        'clone', 'https://u:p@ss_SENTINEL@h.example/o/r', 'p@ss_SENTINEL'
    )
}

# Assert
Assert-Equal -Expected "git clone 'https://***@h.example/o/r' '***'" -Actual $both `
    -Message 'A value is hidden before the URL credential is, so each word is hidden whatever it holds'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - values that hide nothing
$nothing = & $module {
    Format-NativeCommandLine -Command 'git' -Mask @($null, '', 'ab') -Arguments @('config', 'ab')
}
$noMask = & $module { Format-NativeCommandLine -Command 'git' -Mask $null -Arguments @('config', 'ab') }

# Assert
Assert-Equal -Expected 'git config ab' -Actual $nothing -Message 'An empty value, a $null one, and a short one hide nothing'
Assert-Equal -Expected 'git config ab' -Actual $noMask -Message 'and neither does a $null list'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no arguments at all
$bare = & $module { Format-NativeCommandLine -Command 'git' }

# Assert
Assert-Equal -Expected 'git' -Actual $bare -Message 'A command with no arguments is just its name'

exit (Complete-TestRun)
