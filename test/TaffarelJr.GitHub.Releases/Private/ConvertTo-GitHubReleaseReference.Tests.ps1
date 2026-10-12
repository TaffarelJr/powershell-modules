#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1'
$module = Import-Module $manifest -Force -PassThru

$convert = {
    param($Release, $Repository, $PipelineBound)
    ConvertTo-GitHubReleaseReference -Release $Release -Repository $Repository -PipelineBound:$PipelineBound
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a release, and the tag and repository each gives
$forms = @(
    @{
        Release    = 'v1.0.0'
        Repository = $null
        Tag        = 'v1.0.0'
        In         = $null
        Message    = 'A tag is returned as it is, with no repository'
    }
    @{
        Release    = '--web'
        Repository = $null
        Tag        = '--web'
        In         = $null
        Message    = 'whatever it starts with, as it is always sent after a --'
    }
    @{
        Release    = 123
        Repository = $null
        Tag        = '123'
        In         = $null
        Message    = 'A number is a tag, as text'
    }
    @{
        Release    = 'v1'
        Repository = 'o/r'
        Tag        = 'v1'
        In         = 'o/r'
        Message    = 'The -Repository given comes back with it'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v2'; Name = 'Two' }
        Repository = $null
        Tag        = 'v2'
        In         = $null
        Message    = 'An object is read by its TagName, not its title'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 2 }
        Repository = $null
        Tag        = '2'
        In         = $null
        Message    = 'a TagName that is a number included'
    }
    @{
        Release    = @{ tagname = 'v3' }
        Repository = $null
        Tag        = 'v3'
        In         = $null
        Message    = 'A hashtable is read by its key, in any case'
    }
    @{
        Release    = @{ TagName = 'v3'; Keys = 'x'; Repository = 'a/b' }
        Repository = $null
        Tag        = 'v3'
        In         = 'a/b'
        Message    = 'a hashtable holding a Keys entry included'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v4'; Repository = 'a/b' }
        Repository = $null
        Tag        = 'v4'
        In         = 'a/b'
        Message    = 'An object''s Repository is the repository it came from'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v4'; Repository = 'a/b' }
        Repository = 'a/b'
        Tag        = 'v4'
        In         = 'a/b'
        Message    = 'and agrees with the same -Repository'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v4'; Repository = 'https://github.com/A/B' }
        Repository = 'a/b'
        Tag        = 'v4'
        In         = 'github.com/A/B'
        Message    = 'or with the same repository written another way, keeping the release''s host'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v4'; Repository = 'https://ghe.example.com/o/r' }
        Repository = 'git@ghe.example.com:o/r.git'
        Tag        = 'v4'
        In         = 'git@ghe.example.com:o/r.git'
        Message    = 'or written in the SSH form'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v4'; Repository = 'https://ghe.example.com/o/r' }
        Repository = 'o/r'
        Tag        = 'v4'
        In         = 'ghe.example.com/o/r'
        Message    = 'An Enterprise release named by OWNER/REPO alone stays on its own host'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v5'; Repository = '' }
        Repository = 'o/r'
        Tag        = 'v5'
        In         = 'o/r'
        Message    = 'An empty Repository is no repository'
    }
    @{
        Release    = @('v6')
        Repository = $null
        Tag        = 'v6'
        In         = $null
        Message    = 'A list of one tag is that tag'
    }
    @{
        Release    = @([PSCustomObject]@{ TagName = 'v7'; Repository = 'a/b' })
        Repository = $null
        Tag        = 'v7'
        In         = 'a/b'
        Message    = 'A list of one release is that release, with the repository it came from'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $reference = & $module $convert $form.Release $form.Repository $false
    Assert-Equal `
        -Expected @($form.Tag, $form.In) `
        -Actual @($reference.Tag, $reference.Repository) `
        -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no release
$refusals = @(
    @{
        Release = $null
        Like    = 'A release was given, but it is $null: give its tag, or a release from Get-GitHubRelease.'
        Message = '$null is refused rather than read as the latest release'
    }
    @{
        Release = ''
        Like    = "'' is not a release tag: give the tag's name, such as 'v1.0.0', or a release object."
        Message = 'An empty tag is refused'
    }
    @{
        Release = '  '
        Like    = "'  ' is not a release tag: give the tag's name*"
        Message = 'as is a blank one'
    }
    @{
        Release = $true
        Like    = "'True' is not a release tag: give the tag's name*"
        Message = 'A boolean is no tag'
    }
    @{
        Release = @('v1', 'v2')
        Like    = 'Give one release at a time, not a list of 2; call once per release.'
        Message = 'Several releases at once are refused, with advice that fits a parameter not taking pipeline input'
    }
    @{
        Release = @($null)
        Like    = 'A release was given, but it is $null: give its tag, or a release from Get-GitHubRelease.'
        Message = 'A list holding only $null is the $null, which is refused'
    }
    @{
        Release = @('')
        Like    = "'' is not a release tag: give the tag's name, such as 'v1.0.0', or a release object."
        Message = 'and a list holding only an empty tag is that empty tag'
    }
    @{
        Release = [PSCustomObject]@{ Name = 'One' }
        Like    = 'A release object needs a TagName, and this one has none: PSCustomObject.'
        Message = 'An object without a TagName is refused, not sent as its text'
    }
    @{
        Release = [PSCustomObject]@{ TagName = ' ' }
        Like    = 'A release object needs a TagName*'
        Message = 'as is one whose TagName is blank'
    }
)

# Act / Assert
foreach ($refusal in $refusals) {
    Assert-Throws -ScriptBlock {
        & $module $convert $refusal.Release $null $false
    } -MessageLike $refusal.Like -Message $refusal.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a list given to a parameter that takes pipeline input
Assert-Throws -ScriptBlock {
    & $module $convert @('v1', 'v2', 'v3') $null $true
} -MessageLike 'Give one release at a time, not a list of 3; pipe them to name several.' `
    -Message 'A pipeline-bound parameter is answered with advice to pipe them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a release from one repository, and -Repository naming another
$mismatches = @(
    @{
        Release    = [PSCustomObject]@{ TagName = 'v1'; Repository = 'a/b' }
        Repository = 'c/d'
        Like       = 'Release v1 is in a/b, but -Repository names c/d: give one or the other.'
        Message    = 'The release is not looked for in a repository it did not come from'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v1'; Repository = 'https://github.com/a/b' }
        Repository = 'c/d'
        Like       = 'Release v1 is in a/b, but -Repository names c/d: give one or the other.'
        Message    = 'and a github.com release is shown as OWNER/REPO, not as its URL'
    }
    @{
        Release    = [PSCustomObject]@{ TagName = 'v1'; Repository = 'https://github.com/o/r' }
        Repository = 'ghe.example.com/o/r'
        Like       = 'Release v1 is in github.com/o/r, but -Repository names ghe.example.com/o/r:' +
        ' give one or the other.'
        Message    = 'The same OWNER/REPO on another host is another repository, and the host is shown'
    }
)

# Act / Assert
foreach ($mismatch in $mismatches) {
    Assert-Throws -ScriptBlock {
        & $module $convert $mismatch.Release $mismatch.Repository $false
    } -MessageLike $mismatch.Like -Message $mismatch.Message
}

exit (Complete-TestRun)
