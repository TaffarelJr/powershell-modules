#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, reading the new, empty config folder the loopback server's
# fixture points it at: what gh prints for a setting is proved here, which
# the in-process fake gh cannot show. Nothing is written.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$server = Start-FakeGitHubServer
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a setting nobody has set and gh has no default for
    $editor = Get-GitHubConfig -Name 'editor'

    # Assert
    Assert-Equal -Expected '' -Actual $editor -Message 'A setting with no value comes back as an empty string'

    #───────────────────────────────────────────────────────────────────────────
    # Act - one gh gives a default
    $protocol = Get-GitHubConfig -Name 'git_protocol'

    # Assert
    Assert-Equal -Expected 'https' -Actual $protocol `
        -Message 'A setting gh has a default for comes back as that default'

    #───────────────────────────────────────────────────────────────────────────
    # Act - every setting
    $settings = @(Get-GitHubConfig)
    $editorSetting = @($settings | Where-Object Name -CEQ 'editor')

    # Assert
    Assert-Equal -Expected 1 -Actual $editorSetting.Count -Message 'The list names every setting, an empty one included'
    Assert-Equal -Expected '' -Actual $editorSetting[0].Value -Message 'with an empty Value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a global editor and pager, and a host that overrides only the pager
    $configFile = Join-Path $server.ConfigDir 'config.yml'
    $hostsFile = Join-Path $server.ConfigDir 'hosts.yml'
    [System.IO.File]::WriteAllText($configFile, "editor: globalvim`npager: globalless`n")
    [System.IO.File]::WriteAllText($hostsFile, "ghe.example:`n    pager: hostmore`n")

    # Act
    $hostEditor = Get-GitHubConfig -Name 'editor' -Hostname 'ghe.example'
    $hostPager = Get-GitHubConfig -Name 'pager' -Hostname 'ghe.example'
    $globalPager = Get-GitHubConfig -Name 'pager'

    # Assert
    Assert-Equal -Expected 'globalvim' -Actual $hostEditor `
        -Message 'A host that sets no value reads the global value'
    Assert-Equal -Expected 'hostmore' -Actual $hostPager -Message 'one that sets its own reads that'
    Assert-Equal -Expected 'globalless' -Actual $globalPager -Message 'and without -Hostname the global value is read'
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
