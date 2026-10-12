#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') `
    -Force `
    -PassThru

$add = {
    param($InputObject, $Scope)

    Add-GitHubScopeProperty -InputObject $InputObject -Scope $Scope
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed objects and where they were listed from
$listed = @(
    [PSCustomObject]@{ Name = 'A' }
    [PSCustomObject]@{ Name = 'B' }
)
$scope = [ordered]@{
    Repository  = $null
    Environment = 'prod'
}

# Act
$out = @(& $module $add $listed $scope)

# Assert
Assert-Equal -Expected @(
    [PSCustomObject]@{ Name = 'A'; Repository = $null; Environment = 'prod' }
    [PSCustomObject]@{ Name = 'B'; Repository = $null; Environment = 'prod' }
) -Actual $out `
    -Message 'Each object is written out with the scope''s properties after its own, in order, a $null one included'

#───────────────────────────────────────────────────────────────────────────────
# Act - nothing listed
$none = @(& $module $add @() ([ordered]@{ Repository = 'o/r' }))

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'Nothing listed writes nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories given as a URL that carries a credential, as one that does not, and as a token before a host
$withCredential = [PSCustomObject]@{ Name = 'A' }
$withoutCredential = [PSCustomObject]@{ Name = 'B' }
$withToken = [PSCustomObject]@{ Name = 'C' }

# Act
$hidden = @(& $module $add $withCredential ([ordered]@{ Repository = 'https://user:SENTINEL@ghe.example.com/o/r' }))
$plain = @(& $module $add $withoutCredential ([ordered]@{ Repository = 'https://ghe.example.com/o/r' }))
$token = @(& $module $add $withToken ([ordered]@{ Repository = 'SENTINEL@ghe.example.com/o/r' }))

# Assert
Assert-Equal -Expected 'https://***@ghe.example.com/o/r' -Actual $hidden[0].Repository `
    -Message 'A Repository URL carrying a credential is attached with the credential hidden'
Assert-Equal -Expected 'https://ghe.example.com/o/r' -Actual $plain[0].Repository `
    -Message 'one without a credential is attached as it is'
Assert-Equal -Expected '***@ghe.example.com/o/r' -Actual $token[0].Repository `
    -Message 'and a token in front of the host is hidden too'

exit (Complete-TestRun)
