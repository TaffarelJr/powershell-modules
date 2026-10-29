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
# Arrange - one repository written several ways, one with a token
$repositories = @(
    'o/r'
    'https://github.com/o/r'
    'https://www.github.com/o/r.git'
    'https://x-access-token:SENTINEL@github.com/o/r'
)

# Act
$targets = @(
    foreach ($repository in $repositories) {
        & $module { param($r) Format-GitHubItemTarget -Repository $r -Item 'workflow run 5' } $repository
    }
)

# Assert
$expected = @('o/r workflow run 5', 'o/r workflow run 5', 'o/r workflow run 5', 'o/r workflow run 5')
Assert-Equal -Expected $expected -Actual $targets `
    -Message 'The repository is named OWNER/REPO however it was given, and a token in it is never shown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$repository = 'https://user:SENTINEL@ghe.example.com/o/r'

# Act
$target = & $module { param($r) Format-GitHubItemTarget -Repository $r -Item 'cache 7' } $repository

# Assert
Assert-Equal -Expected 'ghe.example.com/o/r cache 7' -Actual $target -Message 'A host other than github.com is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no repository: gh acts in the current directory's

# Act
$targets = @(
    & $module { Format-GitHubItemTarget -Item 'workflow ci.yml' }
    & $module { Format-GitHubItemTarget -Repository $null -Item 'workflow ci.yml' }
    & $module { Format-GitHubItemTarget -Repository '' -Item 'workflow ci.yml' }
)

# Assert
Assert-Equal -Expected @('workflow ci.yml', 'workflow ci.yml', 'workflow ci.yml') -Actual $targets `
    -Message 'With no repository, left out, $null, or empty, the item is named alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no item: the repository itself is the target

# Act
$targets = @(
    & $module { Format-GitHubItemTarget -Repository 'https://user:SENTINEL@github.com/o/r' }
    & $module { Format-GitHubItemTarget -Repository $null }
    & $module { Format-GitHubItemTarget }
)

# Assert
$expected = @('o/r', "the current directory's repository", "the current directory's repository")
Assert-Equal -Expected $expected -Actual $targets `
    -Message 'With no item, the repository is named, or the current directory''s when there is none'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a cache key may end in spaces

# Act
$target = & $module { Format-GitHubItemTarget -Repository 'o/r' -Item 'cache key npm ' }

# Assert
Assert-Equal -Expected 'o/r cache key npm ' -Actual $target -Message 'The item is kept exactly as given'

exit (Complete-TestRun)
