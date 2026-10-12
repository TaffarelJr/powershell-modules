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
    param($Label)

    ConvertTo-GitHubLabelReference -Label $Label
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a label, and what each gives
$forms = @(
    @{
        Given    = 'needs fix'
        Expected = [PSCustomObject]@{ Name = 'needs fix'; Repository = $null }
        Message  = 'Text is the label''s name, with no repository of its own'
    }
    @{
        Given    = [PSCustomObject]@{ Name = 'bug'; Url = 'https://github.com/other/repo/labels/bug'; Color = 'd73a4a' }
        Expected = [PSCustomObject]@{ Name = 'bug'; Repository = 'https://github.com/other/repo' }
        Message  = 'A listed label is read by its Name, and its repository by its Url'
    }
    @{
        Given    = [PSCustomObject]@{ Name = 'a b'; Url = 'https://ghe.example.com/o/r/labels/a%20b' }
        Expected = [PSCustomObject]@{ Name = 'a b'; Repository = 'https://ghe.example.com/o/r' }
        Message  = 'An enterprise label keeps its host'
    }
    @{
        Given    = @{ name = 'docs'; url = 'https://github.com/o/r/labels/docs' }
        Expected = [PSCustomObject]@{ Name = 'docs'; Repository = 'https://github.com/o/r' }
        Message  = 'A hashtable is read by its keys, in any case'
    }
    @{
        Given    = @{ Name = 'kept'; Url = 'https://github.com/o/r/labels/kept'; Keys = 'x' }
        Expected = [PSCustomObject]@{ Name = 'kept'; Repository = 'https://github.com/o/r' }
        Message  = 'and a hashtable holding a Keys entry is read the same, not through that entry'
    }
    @{
        Given    = 'https://github.com/other/repo/labels/good%20first%20issue'
        Expected = [PSCustomObject]@{ Name = 'good first issue'; Repository = 'https://github.com/other/repo' }
        Message  = 'A label''s URL given as text is read like an object''s Url, its name decoded from the URL'
    }
    @{
        Given    = 'https://ghe.example.com/o/r/labels/area%2Fui/'
        Expected = [PSCustomObject]@{ Name = 'area/ui'; Repository = 'https://ghe.example.com/o/r' }
        Message  = 'an enterprise one keeps its host, and a trailing slash is not part of the name'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $reference = & $module $convert $form.Given
    Assert-Equal -Expected $form.Expected -Actual $reference -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository named beside a label, agreeing with its Url or standing alone
$named = {
    param($Label, $Repository)

    ConvertTo-GitHubLabelReference -Label $Label -Repository $Repository
}
$listed = [PSCustomObject]@{ Name = 'bug'; Url = 'https://github.com/o/r/labels/bug' }
$agreeing = @(
    @{
        Repository = 'O/R'
        Expected = 'github.com/o/r'
        Message = 'OWNER/REPO naming the label''s own repository, in any case, keeps the label''s host'
    }
    @{
        Repository = 'github.com/o/r'
        Expected = 'github.com/o/r'
        Message = 'HOST/OWNER/REPO with the same host is used as named'
    }
    @{
        Repository = 'https://github.com/o/r.git'
        Expected = 'https://github.com/o/r.git'
        Message = 'as is the repository''s URL'
    }
    @{ Repository = 'git@github.com:o/r.git'; Expected = 'git@github.com:o/r.git'; Message = 'and its SSH address' }
    @{ Repository = 'r'; Expected = 'r'; Message = 'A bare REPO cannot be compared, so it is left for gh to judge' }
)

# Act / Assert
foreach ($case in $agreeing) {
    $reference = & $module $named $listed $case.Repository
    Assert-Equal -Expected ([PSCustomObject]@{ Name = 'bug'; Repository = $case.Expected }) -Actual $reference `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - an enterprise label beside OWNER/REPO, a bare name beside a repository, and a Url-less label object beside one
$enterprise = & $module $named ([PSCustomObject]@{ Name = 'bug'; Url = 'https://ghe.example.com/o/r/labels/bug' }) 'o/r'
$alone = & $module $named 'bug' 'other/repo'
$urlLess = & $module $named ([PSCustomObject]@{ Name = 'bug'; Color = 'fff' }) 'o/r'

# Assert
Assert-Equal -Expected ([PSCustomObject]@{ Name = 'bug'; Repository = 'ghe.example.com/o/r' }) -Actual $enterprise `
    -Message 'An enterprise label stays on its own host when -Repository names no host'
Assert-Equal -Expected ([PSCustomObject]@{ Name = 'bug'; Repository = 'other/repo' }) -Actual $alone `
    -Message 'A bare name takes the named repository'
Assert-Equal -Expected ([PSCustomObject]@{ Name = 'bug'; Repository = 'o/r' }) -Actual $urlLess `
    -Message 'A label object with no Url takes the named repository'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository named beside a label from another one
$disagreeing = @(
    @{ Repository = 'other/repo'; Shown = 'o/r'; Message = 'Another OWNER/REPO is refused, naming both' }
    @{
        Repository = 'ghe.example.com/o/r'
        Shown = 'github.com/o/r'
        Message = 'as is the same OWNER/REPO on another host, both hosts shown'
    }
    @{ Repository = 'https://ghe.example.com/o/r'; Shown = 'github.com/o/r'; Message = 'given as a URL too' }
)

# Act / Assert
foreach ($case in $disagreeing) {
    Assert-Throws -ScriptBlock {
        & $module $named $listed $case.Repository
    } -MessageLike "'https://github.com/o/r/labels/bug' is in $($case.Shown), but -Repository names $($case.Repository): give one or the other." `
        -Message $case.Message
}

Assert-Throws -ScriptBlock {
    & $module $named 'https://github.com/a/b/labels/bug' 'c/d'
} -MessageLike "'https://github.com/a/b/labels/bug' is in a/b, but -Repository names c/d: give one or the other." `
    -Message 'A label''s URL given as text is compared with -Repository like an object''s'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no label, and why each is refused
$refused = @(
    @{ Given = $null; Pattern = 'A label was given, but it is $null.'; Message = '$null is refused' }
    @{
        Given = @('a', 'b')
        Pattern = 'Give one label at a time, not a list of 2; pipe them to name several.'
        Message = 'A list is refused'
    }
    @{
        Given = [PSCustomObject]@{ Title = 'x' }
        Pattern = 'A label object needs a Name, and this one has none: PSCustomObject.'
        Message = 'An object with no Name is refused'
    }
    @{
        Given = '  '
        Pattern = "'  ' is not a label: give its name, or a label object."
        Message = 'A blank name is refused'
    }
    @{
        Given = [PSCustomObject]@{ Name = ' '; Url = 'https://github.com/o/r/labels/x' }
        Pattern = "' ' is not a label: give its name, or a label object."
        Message = 'as is an object''s blank Name'
    }
    @{
        Given = [PSCustomObject]@{ Name = 'x'; Url = 'https://github.com/o/r/issues/1' }
        Pattern = "'https://github.com/o/r/issues/1' is not a label: a URL must end in /OWNER/REPO/labels/NAME."
        Message = 'A Url that is not a label''s is refused, not guessed at'
    }
    @{
        Given = 'https://github.com/o/r/issues/1'
        Pattern = "'https://github.com/o/r/issues/1' is not a label: a URL must end in /OWNER/REPO/labels/NAME."
        Message = 'as is such a URL given as text, rather than taken as a name'
    }
    @{
        Given = [PSCustomObject]@{ Name = 'bug'; Color = 'fff' }
        Pattern = "The label 'bug' is an object with no Url, so it does not say its repository: give -Repository."
        Message = 'A label object with no Url and no -Repository is refused, not acted on in the current directory''s repository'
    }
    @{
        Given = @{ Name = 'bug' }
        Pattern = "The label 'bug' is an object with no Url, so it does not say its repository: give -Repository."
        Message = 'as is such a hashtable'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $convert $case.Given
    } -MessageLike $case.Pattern -Message $case.Message
}

exit (Complete-TestRun)
