#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name an issue or a pull request, and the operand each gives
$issueUrl = 'https://github.com/o/r/issues/7'
$pullUrl = 'https://github.com/o/r/pull/7'
$forms = @(
    @{ Kind = 'Issue'; Given = 12; Expected = '12'; Message = 'A number is returned as its digits' }
    @{ Kind = 'Issue'; Given = [long]12; Expected = '12'; Message = 'whatever its type' }
    @{ Kind = 'Issue'; Given = '12'; Expected = '12'; Message = 'as is the same number written as text' }
    @{ Kind = 'Issue'; Given = '#12'; Expected = '12'; Message = 'A number with its # is returned without it' }
    @{ Kind = 'Issue'; Given = ' 7 '; Expected = '7'; Message = 'and surrounding spaces are dropped' }
    @{ Kind = 'Issue'; Given = '9999999999'; Expected = '9999999999'; Message = 'Ten digits are still a number' }
    @{ Kind = 'Issue'; Given = $issueUrl; Expected = $issueUrl; Message = 'An issue URL is returned as it is' }
    @{
        Kind = 'Issue'
        Given = 'https://ghe.example.com/o/r/issues/7'
        Expected = 'https://ghe.example.com/o/r/issues/7'
        Message = 'whatever host it is on'
    }
    @{
        Kind = 'Issue'
        Given = "$issueUrl#issuecomment-1"
        Expected = "$issueUrl#issuecomment-1"
        Message = 'and with a fragment after it, which gh ignores'
    }
    @{
        Kind = 'PullRequest'
        Given = $pullUrl
        Expected = $pullUrl
        Message = 'A pull request URL is returned as it is'
    }
    @{
        Kind = 'PullRequest'
        Given = "$pullUrl/files"
        Expected = "$pullUrl/files"
        Message = 'and with a path after it'
    }
    @{
        Kind = 'PullRequest'
        Given = "$pullUrl#discussion_r1"
        Expected = "$pullUrl#discussion_r1"
        Message = 'or a fragment'
    }
    @{
        Kind = 'PullRequest'
        Given = 'feature/new-thing'
        Expected = 'feature/new-thing'
        Message = 'A branch name is returned as it is'
    }
    @{
        Kind = 'PullRequest'
        Given = 'octocat:fix-1'
        Expected = 'octocat:fix-1'
        Message = 'and so is one with its owner'
    }
    @{
        Kind = 'PullRequest'
        Given = 'v2'
        Expected = 'v2'
        Message = 'A branch that starts like a number but is not one stays a name'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 7; Url = $issueUrl }
        Expected = $issueUrl
        Message = 'An object with a Url is read by it, which finds the item in the repository it came from'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 7 }
        Expected = '7'
        Message = 'An object with only a Number is read by that'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = '9' }
        Expected = '9'
        Message = 'whether it is text or a number'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 7; Url = '' }
        Expected = '7'
        Message = 'An empty Url is passed over for the Number'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 7; IsPullRequest = $false; Url = $issueUrl }
        Expected = $issueUrl
        Message = 'An issue that says it is not a pull request is an issue'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ number = 7; url = 'https://api.github.com/repos/o/r/pulls/7'; html_url = $pullUrl }
        Expected = $pullUrl
        Message = 'A raw API object is read by its html_url, not by its REST url'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ number = 7; url = 'https://api.github.com/repos/o/r/pulls/7' }
        Expected = '7'
        Message = 'and without one, by its number, never by the REST url'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ HtmlUrl = $pullUrl; Url = 'https://api.github.com/x' }
        Expected = $pullUrl
        Message = 'HtmlUrl comes first'
    }
    @{ Kind = 'Issue'; Given = @{ Number = 7 }; Expected = '7'; Message = 'A hashtable is read by its keys' }
    @{ Kind = 'Issue'; Given = @{ url = $issueUrl; number = 7 }; Expected = $issueUrl; Message = 'in any case' }
    @{
        Kind = 'Issue'
        Given = @{ Keys = 'x'; Number = 7 }
        Expected = '7'
        Message = 'even when one of its keys is named Keys'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ Number = 7 }
        Expected = '7'
        Message = 'A pull request object''s Number is read the same way'
    }
    @{ Kind = 'Issue'; Given = @(7); Expected = '7'; Message = 'An array of one item is read as that item' }
)

# Act / Assert
foreach ($form in $forms) {
    $operand = Resolve-GitHubItemReference -Item $form.Given -Kind $form.Kind
    Assert-Equal -Expected $form.Expected -Actual $operand -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no item, and why each is refused
$refused = @(
    @{
        Kind = 'Issue'
        Given = '--web'
        Pattern = "'--web' is not an issue: give its number or URL, or an issue object."
        Message = 'A flag is refused, so gh never reads it as an option'
    }
    @{
        Kind = 'PullRequest'
        Given = '--web'
        Pattern = "'--web' is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'for a pull request too, where it is no branch either'
    }
    @{
        Kind = 'Issue'
        Given = '-1'
        Pattern = "'-1' is not an issue: give its number or URL, or an issue object."
        Message = 'A negative number is refused'
    }
    @{
        Kind = 'Issue'
        Given = 'abc'
        Pattern = "'abc' is not an issue: give its number or URL, or an issue object."
        Message = 'A word is not an issue'
    }
    @{
        Kind = 'Issue'
        Given = '12abc'
        Pattern = "'12abc' is not an issue: give its number or URL, or an issue object."
        Message = 'nor is a number with something after it'
    }
    @{
        Kind = 'PullRequest'
        Given = 'two words'
        Pattern = "'two words' is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'A name with a space in it is no branch, as git allows none'
    }
    @{
        Kind = 'Issue'
        Given = 'ftp://example.com/1'
        Pattern = "'ftp://example.com/1' is not an issue: give its number or URL, or an issue object."
        Message = 'A URL that is not http or https is refused'
    }
    @{
        Kind = 'Issue'
        Given = [string][char]0x0663
        Pattern = "* is not an issue: give its number or URL, or an issue object."
        Message = 'An Arabic-Indic digit is not a number gh reads'
    }
    @{
        Kind = 'Issue'
        Given = ([string][char]0xFF10 + [char]0xFF17)
        Pattern = "* is not an issue: give its number or URL, or an issue object."
        Message = 'and nor are full-width digits'
    }
    @{
        Kind = 'Issue'
        Given = '99999999999'
        Pattern = "'99999999999' is not an issue: give its number or URL, or an issue object."
        Message = 'A number of eleven digits is refused'
    }
    @{
        Kind = 'PullRequest'
        Given = [string][char]0x0663
        Pattern = "* is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'An Arabic-Indic digit is no pull request number, and not read as a branch name either'
    }
    @{
        Kind = 'PullRequest'
        Given = '#' + [char]0xFF10 + [char]0xFF17
        Pattern = "* is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'and nor are full-width digits after a #'
    }
    @{
        Kind = 'PullRequest'
        Given = '99999999999'
        Pattern = "'99999999999' is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'and nor is a pull request number of eleven digits'
    }
    @{ Kind = 'Issue'; Given = 0; Pattern = "'0' is not an issue: numbers start at 1."; Message = 'and so is 0' }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 0 }
        Pattern = "'0' is not an issue: numbers start at 1."
        Message = 'which an object''s Number reaches too'
    }
    @{
        Kind = 'Issue'
        Given = $true
        Pattern = "'True' is not an issue: give its number or URL, or an issue object."
        Message = 'A bool is refused'
    }
    @{
        Kind = 'PullRequest'
        Given = [switch]$true
        Pattern = "'True' is not a pull request: give its number, URL, or branch name, or a pull request object."
        Message = 'and so is a switch, which would otherwise be the branch True'
    }
    @{
        Kind = 'Issue'
        Given = $pullUrl
        Pattern = "'$pullUrl' is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests for it."
        Message = 'A pull request URL is not an issue, though gh''s issue commands would act on it'
    }
    @{
        Kind = 'PullRequest'
        Given = $issueUrl
        Pattern = "'$issueUrl' is an issue, not a pull request: use TaffarelJr.GitHub.Issues for it."
        Message = 'and an issue URL is not a pull request'
    }
    @{
        Kind = 'Issue'
        Given = 'https://github.com/o/r'
        Pattern = "'https://github.com/o/r' is not an issue: a URL must end in /OWNER/REPO/issues/NUMBER."
        Message = 'A repository URL is not an issue'
    }
    @{
        Kind = 'PullRequest'
        Given = 'https://api.github.com/repos/o/r/pulls/7'
        Pattern = "*is not a pull request: a URL must end in /OWNER/REPO/pull/NUMBER."
        Message = 'nor is a REST URL a pull request''s'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Number = 7; IsPullRequest = $true }
        Pattern = 'This object is a pull request, not an issue: use TaffarelJr.GitHub.PullRequests for it.'
        Message = 'An object that says it is a pull request is not an issue'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ Number = 7; Url = $issueUrl }
        Pattern = "'$issueUrl' is an issue, not a pull request*"
        Message = 'and an issue object is not a pull request'
    }
    @{
        Kind = 'Issue'
        Given = [PSCustomObject]@{ Title = 'x' }
        Pattern = 'An issue object needs an HtmlUrl, a Url, or a Number, and this one has none: PSCustomObject.'
        Message = 'An object with nothing to read is refused, naming what it lacks'
    }
    @{
        Kind = 'PullRequest'
        Given = @{ Title = 'x' }
        Pattern = 'A pull request object needs an HtmlUrl, a Url, or a Number, and this one has none: Hashtable.'
        Message = 'and so is such a hashtable'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ Number = 12345678901 }
        Pattern = "'12345678901' is not a pull request number: an object's Number must be a whole number of 1 to 10 digits."
        Message = 'An object''s Number too long to be one is refused, never read as a branch name'
    }
    @{
        Kind = 'PullRequest'
        Given = [PSCustomObject]@{ Number = 3.5 }
        Pattern = "'3.5' is not a pull request number: an object's Number must be a whole number of 1 to 10 digits."
        Message = 'and so is a fraction'
    }
    @{
        Kind = 'Issue'
        Given = @{ Number = '#7' }
        Pattern = "'#7' is not an issue number: an object's Number must be a whole number of 1 to 10 digits."
        Message = 'and an object''s Number is digits alone, with no #'
    }
    @{
        Kind = 'PullRequest'
        Given = @('a', 'b', 'c')
        Pattern = 'Give one pull request at a time, not a list of 3; pipe them to name several.'
        Message = 'A list names the kind asked for'
    }
    @{
        Kind = 'Issue'
        Given = @(1, 2)
        Pattern = 'Give one issue at a time, not a list of 2; pipe them to name several.'
        Message = 'An array is refused with a message about arrays'
    }
    @{
        Kind = 'Issue'
        Given = $null
        Pattern = 'An issue was given, but it is $null.'
        Message = 'A $null that was given is refused'
    }
    @{
        Kind = 'Issue'
        Given = @(, $null)
        Pattern = 'An issue was given, but it is $null.'
        Message = 'and so is an array holding only $null'
    }
    @{
        Kind = 'PullRequest'
        Given = @()
        Pattern = 'Give one pull request, not an empty list.'
        Message = 'An empty list says so'
    }
    @{
        Kind = 'PullRequest'
        Given = $null
        Pattern = "A pull request was given, but it is `$null - leave it out to use the current branch's pull request."
        Message = 'saying for a pull request how to mean the current branch''s'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        Resolve-GitHubItemReference -Item $case.Given -Kind $case.Kind
    } -MessageLike ([WildcardPattern]::Escape($case.Pattern).Replace('`*', '*')) -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a list given to a parameter that cannot be piped
Assert-Throws -ScriptBlock {
    Resolve-GitHubItemReference -Item @(2, 3) -Kind Issue -NotPiped
} -MessageLike 'Give one issue at a time, not a list of 2; call once per issue.' `
    -Message '-NotPiped advises one call per issue instead of piping'
Assert-Throws -ScriptBlock {
    Resolve-GitHubItemReference -Item @(2, 3) -Kind PullRequest -NotPiped
} -MessageLike 'Give one pull request at a time, not a list of 2; call once per pull request.' `
    -Message 'and one call per pull request'

#───────────────────────────────────────────────────────────────────────────────
# Act - a URL checked against the repository the caller passes as --repo
$same = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository 'O/R'
$sameHost = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository 'github.com/o/r'
$sameUrl = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository 'https://github.com/o/r.git'
$number = Resolve-GitHubItemReference -Item 7 -Kind Issue -Repository 'c/d'
$sameSsh = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository 'git@github.com:o/r.git'
$unread = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository 'not-a-repository'

# Assert
Assert-Equal -Expected @($issueUrl, $issueUrl, $issueUrl, $issueUrl) -Actual @($same, $sameHost, $sameUrl, $sameSsh) `
    -Message 'A URL in the repository given, in any of its forms and any case, is returned'
Assert-Equal -Expected '7' -Actual $number `
    -Message 'A number names no repository of its own, so there is nothing to check'
Assert-Equal -Expected $issueUrl -Actual $unread `
    -Message 'and a repository given in a form that cannot be read is left for gh to judge'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a URL in another repository than the one given
Assert-Throws -ScriptBlock {
    Resolve-GitHubItemReference -Item 'https://github.com/a/b/issues/1' -Kind Issue -Repository 'c/d'
} -MessageLike "'https://github.com/a/b/issues/1' is in a/b, but -Repository names c/d: give one or the other." `
    -Message 'A URL naming another repository throws, since gh would ignore -Repository'
Assert-Throws -ScriptBlock {
    Resolve-GitHubItemReference -Item ([PSCustomObject]@{ Url = $pullUrl }) -Kind PullRequest `
        -Repository 'ghe.example.com/o/r'
} -MessageLike '*is in github.com/o/r, but -Repository names ghe.example.com/o/r: give one or the other.' `
    -Message 'and so does one on another host'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repository objects, as a listing returns them
$sameRepository = [PSCustomObject]@{ Name = 'r'; NameWithOwner = 'o/r'; StargazerCount = 7 }
$otherRepository = [PSCustomObject]@{ Name = 'x'; NameWithOwner = 'o/x'; StargazerCount = 7 }

# Act
$fromObject = Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository $sameRepository

# Assert
Assert-Equal -Expected $issueUrl -Actual $fromObject -Message 'A repository object as -Repository is read by its name'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Resolve-GitHubItemReference -Item $issueUrl -Kind Issue -Repository $otherRepository
} -MessageLike "'$issueUrl' is in o/r, but -Repository names o/x: give one or the other." `
    -Message 'and one naming another repository throws, naming it, not its text'

exit (Complete-TestRun)
