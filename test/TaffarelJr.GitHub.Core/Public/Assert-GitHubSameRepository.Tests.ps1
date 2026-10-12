#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

$issue = "'https://github.com/o/r/issues/1'"

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one repository written every way, against the item's URL
$accepted = @(
    @{ Repository = 'o/r'; Message = 'OWNER/REPO naming the item''s repository passes' }
    @{ Repository = 'O/R'; Message = 'in any case' }
    @{ Repository = 'GitHub.com/o/r'; Message = 'HOST/OWNER/REPO with the item''s host passes, the host in any case' }
    @{ Repository = 'https://github.com/o/r'; Message = 'and so does the repository''s URL' }
    @{ Repository = 'https://github.com/o/r.git/'; Message = 'with .git and a slash after it' }
    @{ Repository = 'git@github.com:o/r.git'; Message = 'and the SSH form' }
    @{ Repository = 'ssh://git@github.com:22/o/r.git'; Message = 'and an ssh:// URL with a port' }
    @{ Repository = ' o/r '; Message = 'Surrounding spaces are ignored' }
    @{ Repository = 'https://www.github.com/o/r'; Message = 'www.github.com is github.com' }
    @{ Repository = 'https://github.com:443/o/r'; Message = 'A URL''s port is ignored, as gh ignores it' }
    @{ Repository = 'git+ssh://git@github.com/o/r.git'; Message = 'A git+ssh:// URL naming the same repository passes' }
    @{ Repository = 'https://api.github.com/repos/o/other'; Message = 'A REST URL is not comparable' }
    @{ Repository = 'r'; Message = 'A bare REPO is not comparable, so it is left for gh to judge' }
    @{ Repository = 'a/b/c/d'; Message = 'and so is a form with too many parts' }
)

# Act / Assert
foreach ($case in $accepted) {
    $result = @(Assert-GitHubSameRepository -Item $issue -Origin 'https://github.com/o/r/issues/1' -Repository $case.Repository)
    Assert-Equal -Expected 0 -Actual $result.Count -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository with no host against an item on GitHub Enterprise, and the other way round
$origins = @(
    @{
        Origin = 'https://ghe.example.com/o/r/labels/bug'
        Repository = 'o/r'
        Message = 'The host is compared only when both sides give one: an Enterprise item passes against OWNER/REPO'
    }
    @{
        Origin = 'o/r'
        Repository = 'ghe.example.com/o/r'
        Message = 'and an item with no host passes against HOST/OWNER/REPO'
    }
    @{
        Origin = 'not a repository'
        Repository = 'c/d'
        Message = 'An origin that cannot be read is not comparable either'
    }
)

# Act / Assert
foreach ($case in $origins) {
    $result = @(Assert-GitHubSameRepository -Item 'Label bug' -Origin $case.Origin -Repository $case.Repository)
    Assert-Equal -Expected 0 -Actual $result.Count -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - another repository, owner, or host
$refused = @(
    @{ Repository = 'o/other'; Shown = 'o/r'; Message = 'Another repository throws' }
    @{ Repository = 'other/r'; Shown = 'o/r'; Message = 'and so does another owner' }
    @{
        Repository = 'ghe.example.com/o/r'
        Shown = 'github.com/o/r'
        Message = 'and another host, naming the item''s host when both give one'
    }
    @{ Repository = 'git@ghe.example.com:o/r.git'; Shown = 'github.com/o/r'; Message = 'whatever form names it' }
    @{ Repository = 'ghe.example.com:8443/o/r'; Shown = 'github.com/o/r'; Message = 'HOST:PORT/OWNER/REPO included' }
    @{
        Repository = 'github.com:443/o/r'
        Shown = 'github.com/o/r'
        Message = 'whose port is part of the host gh goes to'
    }
    @{
        Repository = 'git+https://github.com/x/y'
        Shown = 'github.com/o/r'
        Message = 'A git+https:// URL naming another repository throws, never passing unchecked'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        Assert-GitHubSameRepository -Item $issue -Origin 'https://github.com/o/r/issues/1' -Repository $case.Repository
    } -MessageLike "'https://github.com/o/r/issues/1' is in $($case.Shown), but -Repository names $($case.Repository): give one or the other." `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an Enterprise origin is named with its host
Assert-Throws -ScriptBlock {
    Assert-GitHubSameRepository -Item 'Release v1' -Origin 'https://ghe.example.com/a/b' -Repository 'c/d'
} -MessageLike 'Release v1 is in ghe.example.com/a/b, but -Repository names c/d: give one or the other.' `
    -Message 'An origin on another host than github.com is shown with its host'

#───────────────────────────────────────────────────────────────────────────────
# Act - the repository to act on, with -PassThru
$named = Assert-GitHubSameRepository -Item 'x' -Origin 'o/r' -Repository 'O/R' -PassThru
$enterprise = Assert-GitHubSameRepository -Item 'x' -Origin 'https://ghe.example.com/o/r/labels/bug' -Repository 'o/r' `
    -PassThru
$bothHosts = Assert-GitHubSameRepository -Item 'x' -Origin 'https://ghe.example.com/o/r' `
    -Repository 'GHE.example.com/o/r' `
    -PassThru
$unread = Assert-GitHubSameRepository -Item 'x' -Origin 'https://github.com/o/r' -Repository ' r ' -PassThru

# Assert
Assert-Equal -Expected 'O/R' -Actual $named `
    -Message '-PassThru returns -Repository as given when neither side names a host'
Assert-Equal -Expected 'ghe.example.com/o/r' -Actual $enterprise `
    -Message 'except when only the item names a host, which keeps it on that host'
Assert-Equal -Expected 'GHE.example.com/o/r' -Actual $bothHosts -Message 'When both name one, -Repository wins'
Assert-Equal -Expected 'r' -Actual $unread -Message 'and a -Repository that is not comparable comes back trimmed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repository objects, as a listing returns them
$same = [PSCustomObject]@{ Name = 'r'; NameWithOwner = 'o/r'; StargazerCount = 7 }
$other = [PSCustomObject]@{ Name = 'x'; NameWithOwner = 'o/x'; StargazerCount = 7 }

# Act
$passed = Assert-GitHubSameRepository -Item 'x' -Origin 'o/r' -Repository $same -PassThru

# Assert
Assert-Equal -Expected 'o/r' -Actual $passed `
    -Message 'A repository object is read by its NameWithOwner, and comes back as that reference'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-GitHubSameRepository -Item 'Issue 1' -Origin 'https://github.com/o/r/issues/1' -Repository $other
} -MessageLike 'Issue 1 is in o/r, but -Repository names o/x: give one or the other.' `
    -Message 'and one naming another repository throws, naming it, not its text'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-GitHubSameRepository -Item 'x' -Origin 'https://github.com/o/r/issues/1' -Repository ' '
} -MessageLike '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.' `
    -Message 'A blank -Repository is refused'

exit (Complete-TestRun)
