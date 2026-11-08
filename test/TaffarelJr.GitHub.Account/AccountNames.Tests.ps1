#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One check across every function in the module: each -Hostname runs through
# Core's Assert-GitHubHostname and each -User through the private
# Assert-GitHubAccountName, so a URL, a space, or a leading dash is refused
# before gh is called. The parameters are found by reflection, so a function
# added later that forgets its validator fails here.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$manifestPath = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1'
$module = Import-Module $manifestPath -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$checks = @{ Hostname = 'Assert-GitHubHostname'; User = 'Assert-GitHubAccountName' }
$commands = @($module.ExportedFunctions.PSBase.Values | Sort-Object -Property Name)
$named = foreach ($command in $commands) {
    foreach ($name in 'Hostname', 'User') {
        if ($command.Parameters.ContainsKey($name)) {
            $validators = $command.Parameters[$name].Attributes.Where({ $_ -is [ValidateScript] })
            [PSCustomObject]@{
                Label     = "$($command.Name) -$name"
                Validator = @($validators.ForEach({ "$($_.ScriptBlock)".Trim() })) -join '; '
                Expected  = "$($checks[$name]) -$name `$_"
            }
        }
    }
}

# Act
$unchecked = @($named.Where({ $_.Validator -cne $_.Expected }).ForEach('Label'))

# Assert
$expected = @(
    'Connect-GitHubAccount -Hostname'
    'Disconnect-GitHubAccount -Hostname'
    'Disconnect-GitHubAccount -User'
    'Get-GitHubAuthStatus -Hostname'
    'Get-GitHubConfig -Hostname'
    'Get-GitHubOrganization -Hostname'
    'Get-GitHubToken -Hostname'
    'Get-GitHubToken -User'
    'Register-GitHubCredentialHelper -Hostname'
    'Set-GitHubConfig -Hostname'
    'Switch-GitHubAccount -Hostname'
    'Switch-GitHubAccount -User'
)
Assert-Equal -Expected $expected -Actual @($named.Label) `
    -Message 'Every function that names a host or an account has its -Hostname and -User'
Assert-Equal -Expected @() -Actual $unchecked -Message 'and each runs through its validator'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each function called with a URL for a host
$cases = @(
    @{ Command = 'Connect-GitHubAccount'; Arguments = @{ Token = 't' } }
    @{ Command = 'Disconnect-GitHubAccount'; Arguments = @{} }
    @{ Command = 'Get-GitHubAuthStatus'; Arguments = @{} }
    @{ Command = 'Get-GitHubConfig'; Arguments = @{} }
    @{ Command = 'Get-GitHubOrganization'; Arguments = @{} }
    @{ Command = 'Get-GitHubToken'; Arguments = @{} }
    @{ Command = 'Register-GitHubCredentialHelper'; Arguments = @{} }
    @{ Command = 'Set-GitHubConfig'; Arguments = @{ Name = 'editor'; Value = 'vim' } }
    @{ Command = 'Switch-GitHubAccount'; Arguments = @{} }
)
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act / Assert
    foreach ($case in $cases) {
        $arguments = $case.Arguments
        Assert-Throws -ScriptBlock {
            & $case.Command @arguments -Hostname 'https://ghe.example'
        } -MessageLike "*'https://ghe.example' is not a host name*" `
            -Message "$($case.Command) refuses a URL for -Hostname"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each function called with a flag for an account
$fake = New-FakeGitHubCli -Output @('gho_fake')
try {
    # Act / Assert
    foreach ($command in 'Disconnect-GitHubAccount', 'Get-GitHubToken', 'Switch-GitHubAccount') {
        Assert-Throws -ScriptBlock {
            & $command -User '--hostname'
        } -MessageLike "*'--hostname' is not an account name*" -Message "$command refuses a flag for -User"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host given but empty, as a lookup that came back with nothing would give it
$fake = New-FakeGitHubCli -Output @('gho_default_host')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubToken -Hostname $null
    } -MessageLike "*'' is not a host name*" -Message 'A $null host is refused, not read as the default host'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
