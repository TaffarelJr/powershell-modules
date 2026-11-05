#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') `
    -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') `
    -Force -PassThru

$mask = {
    param([string[]]$FieldArgument, $Header)
    Get-GitHubApiMask -FieldArgument $FieldArgument -Header $Header
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a key that holds each word of the pattern, in any case
$words = @(
    @{ Key = 'client_secret'; Word = 'secret' }
    @{ Key = 'access_token'; Word = 'token' }
    @{ Key = 'Password'; Word = 'passw' }
    @{ Key = 'passwd'; Word = 'passw' }
    @{ Key = 'credentials'; Word = 'credential' }
    @{ Key = 'AUTHORIZATION'; Word = 'auth' }
    @{ Key = 'api-key'; Word = 'api-key' }
    @{ Key = 'api_key'; Word = 'api_key' }
    @{ Key = 'ApiKey'; Word = 'apikey' }
    @{ Key = 'private_key'; Word = 'private' }
    @{ Key = 'signature'; Word = 'signature' }
)

# Act / Assert
foreach ($row in $words) {
    Assert-Equal -Expected @('hidden-value') `
        -Actual @(& $module $mask @('--field', "$($row.Key)=hidden-value") $null) `
        -Message "A key holding $($row.Word), as in $($row.Key), names a secret"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what gh is given for nested keys and lists
$arguments = @(
    '--field', 'config[secret]=nested'
    '--field', 'config[name]=plain'
    '--field', 'credentials[user]=parent-matched'
    '--field', 'tokens[]=first'
    '--field', 'tokens[]=second'
    '--field', 'tokens[]'
    '--raw-field', 'password=raw-secret'
    '--raw-field', 'title=a=b'
    '--raw-field', 'secret_note=has=equals'
)

# Act
$values = @(& $module $mask $arguments $null)

# Assert
Assert-Equal -Expected @('nested', 'parent-matched', 'first', 'second', 'raw-secret', 'has=equals') `
    -Actual $values `
    -Message 'A nested name, a list, and an empty list are read as gh reads them, and a value keeps its own ='

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that gh types, or that are empty, under a key that names a secret
$typed = @(
    '--field', 'private=true'
    '--field', 'auth=false'
    '--field', 'token=null'
    '--raw-field', 'password='
    '--raw-field', 'secret=True'
)

# Act
$kept = @(& $module $mask $typed $null)

# Assert
Assert-Equal -Expected @('True') -Actual $kept `
    -Message 'true, false, null and an empty value are not returned: hiding them garbles other fields that hold one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - headers
$given = [ordered]@{ Accept = 'application/json'; 'X-Api-Key' = 'header-secret'; Empty = '' }
$headers = @(& $module $mask @() $given)

# Assert
Assert-Equal -Expected @('application/json', 'header-secret') -Actual $headers `
    -Message 'The value of every header is returned, whatever its name, an empty one apart'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - nothing given
$none = @(& $module $mask @() $null)
$noFields = @(& $module { Get-GitHubApiMask -Header @{ X = 'y' } })

# Assert
Assert-Equal -Expected @() -Actual $none -Message 'No fields and no headers return nothing'
Assert-Equal -Expected @('y') -Actual $noFields -Message 'and a call given only headers needs no fields'

exit (Complete-TestRun)
