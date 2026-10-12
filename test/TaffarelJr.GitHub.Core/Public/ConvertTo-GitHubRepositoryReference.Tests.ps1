#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a repository, and the reference each gives
$forms = @(
    @{ Given = 'octocat/hello'; Expected = 'octocat/hello'; Message = 'OWNER/REPO is returned as it is' }
    @{ Given = 'github.example.com/o/r'; Expected = 'github.example.com/o/r'; Message = 'as is HOST/OWNER/REPO' }
    @{ Given = 'https://github.com/o/r'; Expected = 'https://github.com/o/r'; Message = 'and a URL' }
    @{ Given = ' o/r '; Expected = 'o/r'; Message = 'Surrounding spaces are dropped' }
    @{
        Given = 'o/r.git'
        Expected = 'o/r'
        Message = 'A trailing .git is dropped from OWNER/REPO, since gh would read it as part of the name'
    }
    @{ Given = 'o/r/'; Expected = 'o/r'; Message = 'and so is a trailing slash, which gh refuses' }
    @{ Given = 'o/r//'; Expected = 'o/r'; Message = 'or several' }
    @{ Given = @('o/one'); Expected = 'o/one'; Message = 'An array of one repository is read as that repository' }
    @{
        Given = [PSCustomObject]@{ FullName = '  '; full_name = 'o/r' }
        Expected = 'o/r'
        Message = 'A blank FullName is passed over for the next'
    }
    @{ Given = 'ghe.example.com/o/r.git/'; Expected = 'ghe.example.com/o/r'; Message = 'from HOST/OWNER/REPO too' }
    @{
        Given = 'o/my.git-tools'
        Expected = 'o/my.git-tools'
        Message = 'A name that only holds .git inside is left as it is'
    }
    @{
        Given = 'https://github.com/o/r.git'
        Expected = 'https://github.com/o/r.git'
        Message = 'A URL keeps its .git, which gh reads itself'
    }
    @{
        Given = 'git@ghe.example.com:o/r.git'
        Expected = 'git@ghe.example.com:o/r.git'
        Message = 'and so does the SSH form, which gh parses as a URL'
    }
    @{
        Given = 'git@ghe.example.com:o/r'
        Expected = 'git@ghe.example.com:o/r'
        Message = 'which without .git is returned as it is too'
    }
    @{
        Given = 'ghe.example.com:8443/o/r.git/'
        Expected = 'ghe.example.com:8443/o/r'
        Message = 'HOST:PORT/OWNER/REPO, which gh splits as text, loses its .git and slash'
    }
    @{
        Given = 'ssh://git@ghe.example.com/o/r.git'
        Expected = 'ssh://git@ghe.example.com/o/r.git'
        Message = 'An ssh: URL is returned as it is'
    }
    @{
        Given = 'git+https://github.com/o/r.git'
        Expected = 'git+https://github.com/o/r.git'
        Message = 'and so is a git+https: one'
    }
    @{
        Given = 'HTTPS://github.com/o/r.git'
        Expected = 'HTTPS://github.com/o/r.git'
        Message = 'HTTPS:// is plain text to gh, left for gh to refuse'
    }
    @{
        Given = [PSCustomObject]@{ NameWithOwner = 'o/r.git' }
        Expected = 'o/r'
        Message = 'A NameWithOwner gets the same treatment'
    }
    @{
        Given = [PSCustomObject]@{ NameWithOwner = 'o/r'; Url = 'https://ghe.example.com/o/r' }
        Expected = 'https://ghe.example.com/o/r'
        Message = 'An object is read by its Url first, which keeps an Enterprise host'
    }
    @{
        Given = [PSCustomObject]@{ NameWithOwner = 'o/r'; Name = 'r' }
        Expected = 'o/r'
        Message = 'then by its NameWithOwner'
    }
    @{
        Given = [PSCustomObject]@{ FullName = 'o/found' }
        Expected = 'o/found'
        Message = 'then, from a search, by its FullName'
    }
    @{
        Given = [PSCustomObject]@{ Url = ''; NameWithOwner = ''; FullName = 'o/second' }
        Expected = 'o/second'
        Message = 'An empty property is passed over for the next'
    }
    @{
        Given = @{ nameWithOwner = 'o/table' }
        Expected = 'o/table'
        Message = 'A hashtable is read by its keys, in any case'
    }
    @{
        Given = [ordered]@{ Url = 'https://github.com/o/ordered' }
        Expected = 'https://github.com/o/ordered'
        Message = 'and so is an ordered one'
    }
    @{
        Given = @{ Keys = 'x'; NameWithOwner = 'o/keyed' }
        Expected = 'o/keyed'
        Message = 'even when one of its keys is named Keys'
    }
    @{
        Given = [PSCustomObject]@{ Url = 'https://github.com/o/r.git/'; NameWithOwner = 'o/other' }
        Expected = 'https://github.com/o/r.git/'
        Message = 'A Url ending in .git or a slash is still a repository''s web URL'
    }
    @{
        Given = [PSCustomObject]@{
            url = 'https://api.github.com/repos/o/r'
            html_url = 'https://github.com/o/r'
            full_name = 'o/r'
        }
        Expected = 'https://github.com/o/r'
        Message = 'A raw API object''s REST url is passed over for its html_url'
    }
    @{
        Given = [PSCustomObject]@{ url = 'https://api.github.com/repos/o/r'; full_name = 'o/full' }
        Expected = 'o/full'
        Message = 'and with no html_url, for its full_name'
    }
    @{
        Given = [PSCustomObject]@{
            Url = 'https://api.github.com/repos/o/r'
            HtmlUrl = 'https://github.com/o/r/'
            FullName = 'o/r'
        }
        Expected = 'https://github.com/o/r/'
        Message = 'and a re-cased one''s for its HtmlUrl'
    }
    @{
        Given = [PSCustomObject]@{ Url = 'https://github.com/o/r/issues/7'; NameWithOwner = 'o/r' }
        Expected = 'o/r'
        Message = 'An issue''s Url is the item''s own, not its repository''s, so it is passed over'
    }
)

# Act / Assert
foreach ($form in $forms) {
    Assert-Equal -Expected $form.Expected -Actual (ConvertTo-GitHubRepositoryReference -Repository $form.Given) `
        -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - nothing given, which leaves gh to use the current directory's repository
$none = @(ConvertTo-GitHubRepositoryReference -Repository $null)
$listOfNull = @(ConvertTo-GitHubRepositoryReference -Repository @(, $null))
$omitted = @(ConvertTo-GitHubRepositoryReference)

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message '$null returns nothing'
Assert-Equal -Expected 0 -Actual $listOfNull.Count `
    -Message 'and so does an array holding only $null (Resolve-GitHubRepositoryArgument refuses it as given-as-null)'
Assert-Equal -Expected 0 -Actual $omitted.Count -Message 'and so does leaving it out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no repository, and why each is refused
$refused = @(
    @{
        Given = 'GIT@github.com:o/r'
        Message = 'GIT@ is refused like any other user, as gh matches git@ with case'
        Pattern = "'GIT@github.com:o/r' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    }
    @{
        Given = 'org-123@github.com:o/r.git'
        Message = 'An SSH form whose user is not git is refused, as gh cannot read it'
        Pattern = "'org-123@github.com:o/r.git' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    }
    @{
        Given = '--web'
        Message = 'A flag is refused, so gh never reads it as an option'
        Pattern = "*'--web' is not a repository*"
    }
    @{ Given = 'o r'; Message = 'A name with a space in it is refused'; Pattern = "*'o r' is not a repository*" }
    @{
        Given = ''
        Message = 'An empty value is refused as blank, naming the parameter'
        Pattern = '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
    }
    @{
        Given = ' '
        Message = 'and so is a blank one'
        Pattern = '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
    }
    @{
        Given = [PSCustomObject]@{ Title = 'x' }
        Message = 'An object with none of the properties is refused, naming what it lacks'
        Pattern = "A repository object needs a repository's web URL in its Url or HtmlUrl, a NameWithOwner, or a FullName, and this one has none: PSCustomObject."
    }
    @{
        Given = @{ Title = 'x' }
        Message = 'and so is a hashtable with none of the keys'
        Pattern = '*and this one has none: Hashtable.'
    }
    @{
        Given = [PSCustomObject]@{ Url = 'https://github.com/o/r/pull/7' }
        Message = 'and an object whose only Url is an item''s'
        Pattern = '*and this one has none: PSCustomObject.'
    }
    @{
        Given = [PSCustomObject]@{ NameWithOwner = '-x/r' }
        Message = 'A property starting with a dash is refused too'
        Pattern = "*'-x/r' is not a repository*"
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        ConvertTo-GitHubRepositoryReference -Repository $case.Given
    } -MessageLike $case.Pattern -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the messages that name the parameter, for a caller whose parameter is not -Repository
$named = @(
    @{
        Given = ''
        Pattern = '-DestinationRepository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
        Message = '-Name names the parameter in the blank message'
    }
    @{
        Given = @()
        Pattern = '-DestinationRepository is an empty list: give one repository, or leave it out.'
        Message = 'and in the empty-list message'
    }
    @{
        Given = @('a/b', 'c/d')
        Pattern = 'Give one repository at a time for -DestinationRepository, not a list of 2; call once per repository.'
        Message = 'and in the list message'
    }
)

# Act / Assert
foreach ($case in $named) {
    Assert-Throws -ScriptBlock {
        ConvertTo-GitHubRepositoryReference -Repository $case.Given -Name 'DestinationRepository'
    } -MessageLike $case.Pattern -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an empty list
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubRepositoryReference -Repository @()
} -MessageLike '-Repository is an empty list: give one repository, or leave it out.' `
    -Message 'An empty array is refused as an empty list'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - more than one repository at a time
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubRepositoryReference -Repository @('o/a', 'o/b')
} -MessageLike 'Give one repository at a time, not a list of 2; call once per repository.' `
    -Message 'An array is refused with a message about arrays, not about objects'

exit (Complete-TestRun)
