#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifest = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1'
$module = Import-Module $manifest -Force -PassThru

$join = {
    param($Property)
    Join-GitHubReleaseField -Property $Property -Default 'name,tagName,url' -Required 'tagName', 'url'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - chosen fields with and without the required ones
$forms = @(
    @{
        Property = $null
        Expected = 'name,tagName,url'
        Message  = 'Without chosen fields, the default set is sent as it is'
    }
    @{
        Property = @('name')
        Expected = 'name,tagName,url'
        Message  = 'Each required field missing from the chosen ones is added at the end'
    }
    @{
        Property = @('Url, Name')
        Expected = 'url,name,tagName'
        Message  = 'A required field already chosen, spelled as the result spells it, is not added twice'
    }
)

# Act / Assert
foreach ($form in $forms) {
    Assert-Equal -Expected $form.Expected -Actual (& $module $join $form.Property) -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - chosen fields that name nothing
Assert-Throws -ScriptBlock {
    & $module $join @(' , ')
} -MessageLike '-Property names no field*' -Message 'An empty field list is still refused'

exit (Complete-TestRun)
