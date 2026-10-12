#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - keys, and the property name each becomes
$cases = @(
    @{ Key = 'headRefName'; Expected = 'HeadRefName'; Message = 'camelCase gets a capital first letter' }
    @{ Key = 'created_at'; Expected = 'CreatedAt'; Message = 'snake_case has each segment capitalized and joined' }
    @{ Key = '_links'; Expected = 'Links'; Message = 'A leading underscore leaves no empty segment' }
    @{ Key = 'a__b_'; Expected = 'AB'; Message = 'and nor do doubled or trailing ones' }
    @{ Key = 'Already'; Expected = 'Already'; Message = 'PascalCase is left alone' }
    @{ Key = '+1'; Expected = '+1'; Message = 'A key with no letter to capitalize is kept' }
    @{ Key = '___'; Expected = '___'; Message = 'A key of underscores alone keeps its own name' }
    @{ Key = ''; Expected = ''; Message = 'and so does an empty one' }
)

# Act / Assert
foreach ($case in $cases) {
    $name = & $module { param($k) Add-GitHubJsonName -Context (New-GitHubJsonContext) -Name $k } $case.Key
    Assert-Equal -Expected $case.Expected -Actual $name -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the cache a conversion keeps
$context = & $module { New-GitHubJsonContext }
& $module { param($c) Add-GitHubJsonName -Context $c -Name 'created_at' | Out-Null } $context
& $module { param($c) Add-GitHubJsonName -Context $c -Name 'title' | Out-Null } $context

# Assert
Assert-Equal -Expected 'CreatedAt' -Actual $context.Names['created_at'] `
    -Message 'The name is remembered for every later object'
Assert-Equal -Expected @($true, $false) -Actual @($context.DateKeys['created_at'], $context.DateKeys['title']) `
    -Message 'and so is whether it names a date'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - which keys name a date: the endings At, _at, and Date, with their case
$dates = @(
    @{ Key = 'updatedAt'; Expected = $true }
    @{ Key = 'pushed_at'; Expected = $true }
    @{ Key = 'dueDate'; Expected = $true }
    @{ Key = 'format'; Expected = $false }
    @{ Key = 'candidate'; Expected = $false }
    @{ Key = 'UPDATED_AT'; Expected = $false }
)

# Act / Assert
foreach ($date in $dates) {
    $flag = & $module {
        param($k)
        $c = New-GitHubJsonContext
        Add-GitHubJsonName -Context $c -Name $k | Out-Null
        $c.DateKeys[$k]
    } $date.Key
    Assert-Equal -Expected $date.Expected -Actual $flag -Message "'$($date.Key)' names a date: $($date.Expected)"
}

#───────────────────────────────────────────────────────────────────────────────
# Act - names kept as they are
$kept = & $module { Add-GitHubJsonName -Context (New-GitHubJsonContext -KeepFieldNames $true) -Name 'created_at' }

# Assert
Assert-Equal -Expected 'created_at' -Actual $kept -Message 'With KeepFieldNames the key is its own name'

exit (Complete-TestRun)
