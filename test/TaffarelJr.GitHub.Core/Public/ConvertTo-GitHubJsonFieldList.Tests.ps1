#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Act - no field names given, in each way a caller passes "none" on
$omitted = ConvertTo-GitHubJsonFieldList -Default 'number,title'
$givenNull = ConvertTo-GitHubJsonFieldList -Property $null -Default 'number,title'
$none = ConvertTo-GitHubJsonFieldList -Property @() -Default 'number,title'

# Assert
Assert-Equal -Expected 'number,title' -Actual $omitted -Message 'Without -Property the default is used'
Assert-Equal -Expected 'number,title' -Actual $givenNull -Message 'and with a $null one'
Assert-Equal -Expected 'number,title' -Actual $none -Message 'and with an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values written every which way, and the list each gives
$cases = @(
    @{ Given = @('number'); Expected = 'number'; Message = 'One name is the list' }
    @{ Given = @('number', 'title'); Expected = 'number,title'; Message = 'Several values are joined with commas' }
    @{ Given = @('number,title'); Expected = 'number,title'; Message = 'A comma-separated value is split' }
    @{ Given = @(' number , title ', 'url'); Expected = 'number,title,url'; Message = 'Each name is trimmed' }
    @{ Given = @('number,', ',title'); Expected = 'number,title'; Message = 'An empty name between commas is dropped' }
    @{
        Given = @('Number', 'HeadRefName')
        Expected = 'number,headRefName'
        Message = 'The first letter is lower-cased, so a PascalCase property name asks for gh''s field'
    }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (ConvertTo-GitHubJsonFieldList -Property $case.Given -Default 'x') `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - values that name no field at all
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubJsonFieldList -Property '' -Default 'number'
} -MessageLike "*-Property names no field: ''*" -Message 'An empty value throws instead of quietly meaning the default'
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubJsonFieldList -Property ' , ', ' ' -Default 'number'
} -MessageLike "*-Property names no field: ' , ', ' '*such as 'number,title'*" `
    -Message 'and so do blanks and bare commas, quoting what was given'

exit (Complete-TestRun)
