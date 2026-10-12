#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - host names gh can look up
$accepted = @(
    'github.com', 'ghe.example.com', 'GHE.Example.COM', 'my-host_1.example', 'localhost', 'xn--bcher-kva.example',
    'bücher.example', "bu$([char]0x0308)cher.example", 'a-b.c-d', '_x.example'
)

# Act / Assert
foreach ($name in $accepted) {
    Assert-Equal -Expected $true -Actual (Assert-GitHubHostname -Hostname $name) -Message "'$name' passes"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - shapes gh can only fail to find
$refused = @(
    @{ Hostname = ''; Message = 'An empty value is refused, never the default host' }
    @{ Hostname = 'https://github.com'; Message = 'A URL is refused' }
    @{ Hostname = 'ghe.example:8443'; Message = 'and so is a port' }
    @{ Hostname = 'ghe.example/x'; Message = 'and a path' }
    @{ Hostname = 'ghe.example\x'; Message = 'and a backslash' }
    @{ Hostname = 'user@ghe'; Message = 'and a user' }
    @{ Hostname = 'a b'; Message = 'and a space' }
    @{ Hostname = "a`tb"; Message = 'and a tab' }
    @{ Hostname = "a$([char]0x00A0)b"; Message = 'and a no-break space' }
    @{ Hostname = "a$([char]0x200B)b"; Message = 'and a zero-width space' }
    @{ Hostname = "a$([char]0x2028)b"; Message = 'and a line separator' }
    @{ Hostname = '-ghe'; Message = 'and a leading dash, which gh would read as an option' }
    @{ Hostname = '.'; Message = 'A name with no letter or digit is refused' }
    @{ Hostname = '..'; Message = 'and so is ..' }
    @{ Hostname = '#'; Message = 'A # is refused' }
    @{ Hostname = 'a?b'; Message = 'and a ?' }
    @{ Hostname = 'gh*'; Message = 'and a wildcard' }
    @{ Hostname = '[::1]'; Message = 'and an IPv6 address' }
    @{ Hostname = 'github.com.'; Message = 'A trailing dot is refused, since gh stores that as another host' }
    @{ Hostname = 'a..b'; Message = 'and so is an empty label' }
    @{ Hostname = '.a'; Message = 'and a leading dot' }
    @{ Hostname = 'a-'; Message = 'A label ending in a dash is refused' }
    @{ Hostname = 'a.b-.c'; Message = 'wherever it is' }
    @{ Hostname = 'a.-b'; Message = 'and so is one starting with a dash' }
    @{ Hostname = "$([char]0x0308)a.example"; Message = 'and one starting with a combining mark' }
)

# Act / Assert
foreach ($case in $refused) {
    $like = [WildcardPattern]::Escape("'$($case.Hostname)' is not a host name: give it bare, such as github.com - labels of letters, digits, dashes, and underscores joined by single dots, none starting or ending with a dash, and no scheme, port, path, space, or trailing dot - or leave -Hostname out for the default host.")
    Assert-Throws -ScriptBlock {
        Assert-GitHubHostname -Hostname $case.Hostname
    } -MessageLike $like -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names longer than DNS allows, and the longest it does
$longLabel = ('a' * 64) + '.com'
$longName = ((@('a' * 50) * 6) -join '.')
$longest = ((@('a' * 63) * 4) -join '.').Substring(0, 253)

# Act / Assert
Assert-Equal -Expected $true -Actual (Assert-GitHubHostname -Hostname $longest) `
    -Message 'A name of 253 characters whose labels are no longer than 63 passes'
foreach ($name in $longLabel, $longName, ((([string][char]0x65E5) * 63) + '.com')) {
    Assert-Throws -ScriptBlock {
        Assert-GitHubHostname -Hostname $name
    } -MessageLike "'$name' is not a host name DNS can hold: a label is at most 63 octets in its ASCII (Punycode) form, and the whole name at most 253." `
        -Message "A name of $($name.Length) characters whose ASCII form has a label over 63 octets, or is over 253 in all, is refused"
}

exit (Complete-TestRun)
