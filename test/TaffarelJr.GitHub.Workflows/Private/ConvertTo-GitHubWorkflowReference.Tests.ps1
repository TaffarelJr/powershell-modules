#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every way to name a workflow, and the reference each gives
$dynamic = [PSCustomObject]@{
    Id    = [long]132478870
    Name  = 'Dependabot Updates'
    Path  = 'dynamic/dependabot/dependabot-updates'
    State = 'active'
}
$forms = @(
    @{ Given = 'ci.yml'; Expected = 'ci.yml'; Message = 'A file name is returned as it is' }
    @{ Given = 'Release Drafter'; Expected = 'Release Drafter'; Message = 'as is a name' }
    @{ Given = ' ci.yml '; Expected = 'ci.yml'; Message = 'with surrounding spaces dropped' }
    @{ Given = '--web'; Expected = '--web'; Message = 'Text that looks like an option is a workflow too' }
    @{ Given = 42; Expected = '42'; Message = 'A number is the workflow id' }
    @{ Given = [long]42; Expected = '42'; Message = 'whatever its numeric type' }
    @{
        Given    = $dynamic
        Expected = '132478870'
        Message  = 'A workflow object is read by its Id, so a dynamic workflow''s Path is never sent'
    }
    @{
        Given    = [PSCustomObject]@{ Id = 'W_kwDO'; Path = '.github/workflows/ci.yml' }
        Expected = '.github/workflows/ci.yml'
        Message  = 'An Id that is not a number is passed over for the Path'
    }
    @{
        Given    = [PSCustomObject]@{ Path = '.github/workflows/ci.yml' }
        Expected = '.github/workflows/ci.yml'
        Message  = 'An object with only a Path is read by it'
    }
    @{
        Given    = [PSCustomObject]@{ DatabaseId = 123; WorkflowName = 'CI'; WorkflowDatabaseId = 777 }
        Expected = '777'
        Message  = 'A run object is read by its WorkflowDatabaseId, never by its own DatabaseId'
    }
    @{ Given = @{ id = 9 }; Expected = '9'; Message = 'A hashtable is read by its keys, in any case' }
    @{ Given = @($dynamic); Expected = '132478870'; Message = 'A collection of one object is read as that object' }
    @{ Given = @('ci.yml'); Expected = 'ci.yml'; Message = 'as is a collection of one name' }
    @{ Given = [ordered]@{ PATH = 'a.yml' }; Expected = 'a.yml'; Message = 'an ordered one too' }
    @{
        Given    = [ordered]@{ Keys = 'k'; Id = 3 }
        Expected = '3'
        Message  = 'and one holding a Keys entry'
    }
    @{
        Given    = [PSCustomObject]@{ Id = $null; Path = ''; WorkflowDatabaseId = 5 }
        Expected = '5'
        Message  = 'Empty values are passed over for the next one'
    }
)

# Act / Assert
foreach ($form in $forms) {
    $reference = & $module { param($w) ConvertTo-GitHubWorkflowReference -Workflow $w } $form.Given
    Assert-Equal -Expected $form.Expected -Actual $reference -Message $form.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no workflow, and why each is refused
$refused = @(
    @{
        Given   = $null
        Message = 'A bound $null is refused, not taken for some default'
        Pattern = '*A workflow was given, but it is $null*'
    }
    @{
        Given   = @($null)
        Message = 'as is a collection holding only $null, with the same message'
        Pattern = 'A workflow was given, but it is $null.'
    }
    @{
        Given   = @()
        Message = 'An empty collection, as a filter that matched nothing gives, is refused as empty'
        Pattern = 'Give one workflow, not an empty list.'
    }
    @{
        Given   = '   '
        Message = 'Blank text is refused'
        Pattern = "'   ' is not a workflow: give its id, name, or file name, or a workflow object."
    }
    @{ Given = $true; Message = 'A bool is refused'; Pattern = "*'True' is not a workflow*" }
    @{ Given = [switch]::new($true); Message = 'as is a switch'; Pattern = "*'True' is not a workflow*" }
    @{
        Given   = @('a.yml', 'b.yml')
        Message = 'A list is refused, naming its size'
        Pattern = 'Give one workflow at a time, not a list of 2; pipe them to name several.'
    }
    @{
        Given   = [PSCustomObject]@{ Key = 'npm-abc' }
        Message = 'An object with nothing that names a workflow is refused, naming what it lacks'
        Pattern = '*needs an Id, a Path, or a WorkflowDatabaseId*PSCustomObject*'
    }
    @{
        Given   = [PSCustomObject]@{ Id = $null; Path = ' ' }
        Message = 'as is one whose values are all empty'
        Pattern = '*needs an Id, a Path, or a WorkflowDatabaseId*'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module { param($w) ConvertTo-GitHubWorkflowReference -Workflow $w } $case.Given
    } -MessageLike $case.Pattern -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a list given to a -Workflow that takes no pipeline input
$list = @('a.yml', 'b.yml')

# Act / Assert
Assert-Throws -ScriptBlock {
    & $module { param($w) ConvertTo-GitHubWorkflowReference -Workflow $w -NotPiped } $list
} -MessageLike 'Give one workflow at a time, not a list of 2; call once per workflow.' `
    -Message 'A list is refused without advice to pipe them, where they cannot be piped'

exit (Complete-TestRun)
