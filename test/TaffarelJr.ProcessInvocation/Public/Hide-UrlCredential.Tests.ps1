#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every shape of credential, and the text each leaves
$hidden = @(
    @{
        Given = 'https://x-access-token:SENTINEL@github.com/o/r'
        Expected = 'https://***@github.com/o/r'
        Message = 'USER:PASSWORD@ after a scheme is hidden'
    }
    @{
        Given = 'Cloning https://x-access-token:SENTINEL@github.com/o/r failed.'
        Expected = 'Cloning https://***@github.com/o/r failed.'
        Message = 'and the text around the URL is kept'
    }
    @{
        Given = 'https://SENTINEL@github.com/o/r'
        Expected = 'https://***@github.com/o/r'
        Message = 'A token alone after a scheme is hidden'
    }
    @{
        Given = 'ssh://SENTINEL@ghe.example.com:2222/o/r.git'
        Expected = 'ssh://***@ghe.example.com:2222/o/r.git'
        Message = 'and so is any user of an ssh: URL, whose port and path are kept'
    }
    @{
        Given = "Cloning https://x-access-token:SENTINEL@github.com/o/r.git failed`nand ssh://git@host/r.git too"
        Expected = "Cloning https://***@github.com/o/r.git failed`nand ssh://***@host/r.git too"
        Message = 'Every URL''s user information is hidden, on every line'
    }
    @{
        Given = 'user:SENTINEL@ghe.example.com/o/r'
        Expected = '***@ghe.example.com/o/r'
        Message = 'USER:PASSWORD@ without a scheme is hidden'
    }
    @{
        Given = 'SENTINEL@ghe.example.com/o/r'
        Expected = '***@ghe.example.com/o/r'
        Message = 'and so is a token alone before a host and a slash'
    }
    @{
        Given = 'SENTINEL@ghe.example.com:8443/o/r'
        Expected = '***@ghe.example.com:8443/o/r'
        Message = 'or before a host, a port, and a slash'
    }
    @{
        Given = 'SENTINEL@[::1]:22/o/r'
        Expected = '***@[::1]:22/o/r'
        Message = 'or before a bracketed host'
    }
    @{
        Given = 'https://me@example.com:pass word@github.com/o/r'
        Expected = 'https://***@github.com/o/r'
        Message = 'An e-mail address as the user, and a space in the password, are hidden whole'
    }
    @{
        Given = 'https://u:SENTINEL@a@b/c@github.com/o/r'
        Expected = 'https://***@github.com/o/r'
        Message = 'and so is a password holding @ and /'
    }
    @{
        Given = '--repo=https://u:SENTINEL@github.com/o/r'
        Expected = '--repo=https://***@github.com/o/r'
        Message = 'A URL inside a --flag=value argument is hidden'
    }
    @{
        Given = 'a https://u:SENTINEL@h.example/o/r and https://v:SENTINEL@ghe.example.com/x/y'
        Expected = 'a https://***@h.example/o/r and https://***@ghe.example.com/x/y'
        Message = 'Each of several URLs is hidden on its own'
    }
    @{
        Given = 'a,SENTINEL@h/o'
        Expected = '***@h/o'
        Message = 'A token alone after a comma is hidden, with the text the comma joins it to'
    }
    @{
        Given = 'mail: me@example.com'
        Expected = '***@example.com'
        Message = 'An @ after any colon hides everything up to it: too much, never too little'
    }
)

# Act / Assert
foreach ($case in $hidden) {
    Assert-Equal -Expected $case.Expected -Actual (Hide-UrlCredential -Text $case.Given) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - passwords pasted in raw, holding characters a URL would encode
$raw = @(
    @{ Text = 'Cloning https://user:p@ssFAKETOKEN@host/r.git failed'; Form = "an '@'" }
    @{ Text = 'Cloning https://user:ab/FAKETOKEN@host/r.git failed'; Form = "a '/'" }
    @{ Text = 'Cloning https://user:ab FAKETOKEN@host/r.git failed'; Form = 'a space' }
    @{ Text = 'Cloning https://user:ab FAKE TOKEN@host/r.git failed'; Form = 'two spaces, with a path after the host' }
    @{ Text = 'Cloning https://user:p@ss/word@host/r.git failed'; Form = "an '@' and then a '/'" }
    @{ Text = 'Cloning https://user@name:pw@host/r.git failed'; Form = "a user name holding an '@'" }
    @{
        Text = 'Cloning https://me@example.com:FAKETOKEN@host/r.git failed'
        Form = 'an e-mail address as the user name'
    }
    @{ Text = 'Cloning https://p@ssFAKETOKEN@host/r.git failed'; Form = "a token as the user name, holding an '@'" }
    @{ Text = 'Cloning https://me@example.com:FAKE/TOKEN@host/r.git failed'; Form = "an e-mail user name and a '/'" }
    @{ Text = 'Cloning https://me@example.com:FAKE TOKEN@host/r.git failed'; Form = 'an e-mail user name and a space' }
    @{ Text = 'Cloning https://me@example.com:FAKE#TOKEN@host/r.git failed'; Form = "an e-mail user name and a '#'" }
    @{ Text = 'Cloning https://me@example.com:FAKE?TOKEN@host/r.git failed'; Form = "an e-mail user name and a '?'" }
    @{ Text = 'Cloning https://user:1234 FAKETOKEN@host/r.git failed'; Form = 'digits and then a space' }
    @{ Text = 'Cloning https://user[1]:FAKETOKEN@host/r.git failed'; Form = "a user name holding a '['" }
    @{ Text = 'Cloning https://FAKE[TOKEN@host/r.git failed'; Form = "a token as the user name, holding a '['" }
    @{ Text = 'Cloning https://user:p@ss word@host/r.git failed'; Form = "an '@' and then a word holding an '@'" }
    @{ Text = 'Cloning https://[1]:FAKETOKEN@host/r.git failed'; Form = "a bracketed user name '[1]'" }
    @{ Text = 'Cloning https://[ab]:FAKETOKEN@host/r.git failed'; Form = "a bracketed user name '[ab]'" }
    @{ Text = 'Cloning https://[a.b]:FAKETOKEN@host/r.git failed'; Form = "a bracketed user name '[a.b]'" }
    @{
        Text = 'Cloning https://[::1]:FAKETOKEN@host/r.git failed'
        Form = 'a bracketed user name shaped like an IPv6 address'
    }
    @{ Text = 'Cloning https://user:123/FAKE@host/r.git failed'; Form = "digits and a '/' before a dot-less host" }
    @{ Text = 'Cloning https://a b:FAKE@host/r.git failed'; Form = 'a user name holding a space' }
)

# Act / Assert
foreach ($row in $raw) {
    Assert-Equal -Expected 'Cloning https://***@host/r.git failed' -Actual (Hide-UrlCredential -Text $row.Text) `
        -Message "A credential holding $($row.Form) is hidden whole"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - more shapes, each with the text it leaves
$shapes = @(
    @{ Text = 'https://user:123/FAKETOKEN@host.example/r.git'; Expected = 'https://***@host.example/r.git' }
    @{ Text = 'https://user:8080/FAKETOKEN@localhost/r.git'; Expected = 'https://***@localhost/r.git' }
    @{ Text = 'https://user:22/FAKETOKEN@10.0.0.1/r.git'; Expected = 'https://***@10.0.0.1/r.git' }
    @{
        Text = 'Cloning https://user:FAKETOKEN@[::1]:8080/r.git failed'
        Expected = 'Cloning https://***@[::1]:8080/r.git failed'
    }
    @{ Text = 'https://me@example.com:1234 FAKE@host/r.git'; Expected = 'https://***@host/r.git' }
    @{ Text = 'Cloning https://user:a b c@host failed'; Expected = 'Cloning https://***@host failed' }
    @{ Text = 'url=https://user:A@host/x,https://u2:B@h2/y'; Expected = 'url=https://***@host/x,https://***@h2/y' }
    @{ Text = 'url=https://user:A@host/x;https://u2:B@h2/y'; Expected = 'url=https://***@host/x;https://***@h2/y' }
    @{ Text = 'https://user:A@host/x?u=https://u2:B@h2/y'; Expected = 'https://***@host/x?u=https://***@h2/y' }
    @{ Text = 'https://h1,https://u:FAKE@h2/x'; Expected = 'https://h1,https://***@h2/x' }
    @{ Text = 'https://u:p@ss/word@host https://u2:pw2@host2/x'; Expected = 'https://***@host https://***@host2/x' }
    @{ Text = "https://u:p@ss?word@host`n https://u2:pw2@host2/x"; Expected = "https://***@host`n https://***@host2/x" }
    @{ Text = 'https://u:p@ss/@w rd@host/r.git'; Expected = 'https://***@host/r.git' }
)

# Act / Assert
foreach ($row in $shapes) {
    Assert-Equal -Expected $row.Expected -Actual (Hide-UrlCredential -Text $row.Text) `
        -Message "'$($row.Text)' becomes '$($row.Expected)'"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - text that holds no credential
$kept = @(
    @{ Given = 'git@github.com:o/r.git'; Message = 'The SSH form''s user is not a credential' }
    @{ Given = 'see me@example.com for help'; Message = 'An e-mail address with no colon before it is kept' }
    @{ Given = 'https://github.com/o/r'; Message = 'A URL with no user is kept' }
    @{ Given = 'https://github.com/o/r.git, mail@example.com'; Message = 'and so is an @ in a later word after one' }
    @{ Given = 'https://host/pkg@1.0 is down, mail@example.com'; Message = 'or in a path with no colon before it' }
    @{ Given = 'https://h1,https://h2/x and me@mail.com'; Message = 'or after URLs joined by a comma' }
    @{ Given = 'Calling repos/o/r failed: gh api repos/o/r (exit 1)'; Message = 'and so is text with no @' }
    @{ Given = 'tok@[::1 /o'; Message = 'A token alone before a bracket that never closes is not hidden' }
    @{ Given = 'tok@/o/r'; Message = 'nor one before no host at all' }
    @{ Given = 'tok@h:/o'; Message = 'nor one before a host and a colon with no port' }
    @{ Given = 'tok@h:22'; Message = 'nor one before a host and a port with no slash' }
    @{ Given = ''; Message = 'and empty text' }
)

# Act / Assert
foreach ($case in $kept) {
    Assert-Equal -Expected $case.Given -Actual (Hide-UrlCredential -Text $case.Given) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an @ after a colon that is not a credential's, hidden up to it
# because it cannot be told apart from one
$over = @(
    @{ Text = 'https://host:8080/pkg@1.0/x'; Expected = 'https://***@1.0/x' }
    @{ Text = 'https://host:8080/@scope/pkg'; Expected = 'https://***@scope/pkg' }
    @{ Text = 'https://host:8080/pkg@2.1.3/x'; Expected = 'https://***@2.1.3/x' }
    @{ Text = 'https://[::1]:8080/r.git?ref=a@b'; Expected = 'https://***@b' }
    @{ Text = 'https://[fe80::1%25eth0]:8080/x contact me@mail.com'; Expected = 'https://***@mail.com' }
    @{ Text = 'http://[v1.fe80::a+en1]/x and me@mail.com'; Expected = 'http://***@mail.com' }
    @{ Text = 'Cloning https://x:y and contact me@host.com'; Expected = 'Cloning https://***@host.com' }
    @{ Text = 'https://u:p@ss/word@host me@mail.com'; Expected = 'https://***@mail.com' }
)

# Act / Assert
foreach ($row in $over) {
    Assert-Equal -Expected $row.Expected -Actual (Hide-UrlCredential -Text $row.Text) `
        -Message "'$($row.Text)' becomes '$($row.Expected)': too much, never too little"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the documented gaps, which a caller must keep in mind
$gaps = @(
    @{
        Given = 'https://u:pa://SENTINEL@h/o/r'
        Expected = 'https://u:pa://***@h/o/r'
        Message = 'A password holding :// is hidden only after it'
    }
    @{
        Given = 'https://us/er:SENTINEL@h/o/r'
        Expected = 'https://us/***@h/o/r'
        Message = 'a user name holding a slash only after the slash'
    }
    @{
        Given = 'us er@ghe.example.com/o/r'
        Expected = 'us ***@ghe.example.com/o/r'
        Message = 'and, without a scheme, a user name alone only after its space'
    }
    @{
        Given = 'https://h/o/r?access_token=SENTINEL'
        Expected = 'https://h/o/r?access_token=SENTINEL'
        Message = 'A token in a query string is not user information and is kept'
    }
)

# Act / Assert
foreach ($case in $gaps) {
    Assert-Equal -Expected $case.Expected -Actual (Hide-UrlCredential -Text $case.Given) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - hiding what it returned
$givens = @($hidden + $kept + $gaps | ForEach-Object { $_.Given }) +
@($raw + $shapes + $over | ForEach-Object { $_.Text })
foreach ($given in $givens) {
    $once = Hide-UrlCredential -Text $given
    Assert-Equal -Expected $once -Actual (Hide-UrlCredential -Text $once) `
        -Message "'$once' hidden again is unchanged"
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$asOne = Hide-UrlCredential -Text "Reading: the token`nsee me@example.com"
$lines = @('Reading: the token', 'see me@example.com')
$perLine = @($lines | Hide-UrlCredential)

# Assert
Assert-Equal -Expected '***@example.com' -Actual $asOne `
    -Message 'One text is read as one, so an @ on a later line hides the lines before it'
Assert-Equal -Expected $lines -Actual $perLine `
    -Message 'while lines piped in are each hidden on their own'

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromNull = Hide-UrlCredential -Text $null
$byPosition = Hide-UrlCredential 'https://u:SENTINEL@h/o'

# Assert
Assert-Equal -Expected '' -Actual $fromNull -Message '$null gives empty text'
Assert-Equal -Expected 'https://***@h/o' -Actual $byPosition -Message 'and -Text is the first positional parameter'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a long line of JSON, full of colons, with an @ at its end
$line = ('"a":1,' * 17000) + '"by":"me@example.com"'
$clock = [System.Diagnostics.Stopwatch]::StartNew()

# Act
$shown = Hide-UrlCredential -Text $line
$seconds = $clock.Elapsed.TotalSeconds

# Assert
Assert-Equal -Expected '***@example.com"' -Actual $shown -Message 'A long line is hidden as a short one is'
Assert-That -Condition ($seconds -lt 60) `
    -Message "in time that grows with its length ($([Math]::Round($seconds, 1)) s; its square would take hours)"

exit (Complete-TestRun)
