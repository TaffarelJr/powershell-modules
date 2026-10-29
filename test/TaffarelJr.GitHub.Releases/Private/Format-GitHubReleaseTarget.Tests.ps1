#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') `
    -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act
$actual = & $module { Format-GitHubReleaseTarget -Tag 'v1.0.0' -Repository 'ghe.example.com/o/r' }

# Assert
Assert-Equal -Expected 'ghe.example.com/o/r release v1.0.0' -Actual $actual `
    -Message 'A release with a repository is named in it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$actual = & $module { Format-GitHubReleaseTarget -Tag 'v1.0.0' -Repository $null }

# Assert
Assert-Equal -Expected 'release v1.0.0' -Actual $actual `
    -Message 'and one in the current directory''s repository by its tag alone'

#───────────────────────────────────────────────────────────────────────────────
# Act
$actual = & $module { Format-GitHubReleaseTarget -Tag 'v1' -Repository 'https://user:SENTINEL@www.github.com/o/r.git' }

# Assert
Assert-Equal -Expected 'o/r release v1' -Actual $actual `
    -Message 'A repository URL is named OWNER/REPO, without the credential it carried'

#───────────────────────────────────────────────────────────────────────────────
# Act
$actual = & $module {
    Format-GitHubReleaseTarget -Tag 'v1' -Repository ([PSCustomObject]@{ Url = 'https://ghe.example.com/o/r' })
}

# Assert
Assert-Equal -Expected 'ghe.example.com/o/r release v1' -Actual $actual `
    -Message 'and a repository object by its Url, on its own host'

exit (Complete-TestRun)
