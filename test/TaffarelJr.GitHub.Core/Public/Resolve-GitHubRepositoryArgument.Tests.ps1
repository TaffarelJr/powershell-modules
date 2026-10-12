#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Act - left out, given as text, and given as an object
$omitted = @(Resolve-GitHubRepositoryArgument -Value $null -Given $false)
$text = Resolve-GitHubRepositoryArgument -Value ' o/r ' -Given $true
$object = Resolve-GitHubRepositoryArgument -Value ([PSCustomObject]@{ Url = 'https://ghe.example.com/o/r' }) `
    -Given $true

# Assert
Assert-Equal -Expected 0 -Actual $omitted.Count `
    -Message 'A parameter left out gives nothing, for the current directory''s repository'
Assert-Equal -Expected 'o/r' -Actual $text -Message 'A value is read as ConvertTo-GitHubRepositoryReference reads it'
Assert-Equal -Expected 'https://ghe.example.com/o/r' -Actual $object -Message 'an object included'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value that was given but names nothing
$refused = @(
    @{
        Arguments = @{ Value = $null; Given = $true }
        Like = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'A $null that was given throws, saying how to mean the current repository'
    }
    @{
        Arguments = @{ Value = [System.Collections.Generic.HashSet[object]]::new([object[]]@($null)); Given = $true }
        Like = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'and so is any other list holding only $null, a HashSet say'
    }
    @{
        Arguments = @{ Value = @($null); Given = $true }
        Like = "-Repository was given, but it is `$null - leave it out to use the current directory's repository."
        Message = 'An array holding only $null, such as @($lookup), is given-as-null too'
    }
    @{
        Arguments = @{ Value = $null; Given = $true; Name = 'Source'; Omitted = "the destination's parent" }
        Like = "-Source was given, but it is `$null - leave it out to use the destination's parent."
        Message = 'naming the parameter and what leaving it out means'
    }
    @{
        Arguments = @{ Value = ''; Given = $true }
        Like = '-Repository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
        Message = 'A blank value throws as ConvertTo-GitHubRepositoryReference does'
    }
    @{
        Arguments = @{ Value = ' '; Given = $true; Name = 'Source' }
        Like = '-Source is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
        Message = 'naming the parameter -Name gives'
    }
    @{
        Arguments = @{ Value = @('a/b', 'c/d'); Given = $true }
        Like = 'Give one repository at a time, not a list of 2; call once per repository.'
        Message = 'and so does a list'
    }
    @{
        Arguments = @{ Value = 'o/r'; Given = $true; Name = '-Repository' }
        Like = "*'-Repository' is not a parameter name: give it without its dash."
        Message = '-Name is the parameter''s name without its dash'
    }
    @{
        Arguments = @{ Value = 'o/r'; Given = $true; Omitted = ' ' }
        Like = "*-Omitted is blank: give what leaving the parameter out means, or leave it out."
        Message = 'and -Omitted is not blank'
    }
)

# Act / Assert
foreach ($case in $refused) {
    $arguments = $case.Arguments
    Assert-Throws -ScriptBlock {
        Resolve-GitHubRepositoryArgument @arguments
    } -MessageLike ([WildcardPattern]::Escape($case.Like).Replace('`*', '*')) -Message $case.Message
}

exit (Complete-TestRun)
