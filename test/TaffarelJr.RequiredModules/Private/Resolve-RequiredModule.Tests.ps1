#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the object Get-RequiredModule returns
$given = [PSCustomObject]@{
    Name             = 'Pester'
    MinimumVersion   = [Version]'5.0.0'
    DocumentationUrl = 'https://pester.dev'
}

# Act
$resolved = & $module { Resolve-RequiredModule @args } -Module $given

# Assert
Assert-Equal -Expected 'Pester' -Actual $resolved.Name -Message 'The name comes back'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $resolved.MinimumVersion -Message 'and the minimum version'
Assert-Equal -Expected 'https://pester.dev' -Actual $resolved.DocumentationUrl -Message 'and the documentation link'

#───────────────────────────────────────────────────────────────────────────────
# Act - a hand-made object with a name and a version written as text, and one with a name alone
$text = & $module { Resolve-RequiredModule @args } `
    -Module ([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = '5.0.0' })
$nameOnly = & $module { Resolve-RequiredModule @args } -Module ([PSCustomObject]@{ Name = 'Pester' })

# Assert
Assert-Equal -Expected ([Version]'5.0.0') -Actual $text.MinimumVersion `
    -Message 'A version written as text is read as a version'
Assert-That -Condition ($null -eq $text.DocumentationUrl) -Message 'and a missing documentation link is $null'
Assert-That -Condition ($null -eq $nameOnly.MinimumVersion) `
    -Message 'A name alone has no minimum version, so any version will do'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - things that are not a required module
$notObjects = @(
    @{ Value = 'Pester'; Type = 'String'; Case = 'the name as text' }
    @{ Value = $null; Type = '$null'; Case = '$null' }
    @{ Value = 5; Type = 'Int32'; Case = 'a number' }
    @{ Value = @{ Name = 'Pester' }; Type = 'Hashtable'; Case = 'a hashtable' }
    @{
        Value = [PSCustomObject]@{ MinimumVersion = [Version]'1.0.0' }
        Type  = 'PSCustomObject'
        Case  = 'an object with no Name'
    }
)

# Act / Assert
foreach ($case in $notObjects) {
    Assert-Throws -ScriptBlock { & $module { Resolve-RequiredModule @args } -Module $case.Value } `
        -MessageLike "A required module must be an object with a Name property*got $($case.Type)*" `
        -Message "$($case.Case) is refused, saying what is expected and what it was given"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names that are not a package name, and versions that are not a version
$badNames = @(
    @{ Name = 'Az*'; Case = 'a wildcard' }
    @{ Name = '-Name'; Case = 'a leading dash' }
    @{ Name = '../Pester'; Case = 'a path' }
    @{ Name = ''; Case = 'an empty name' }
    @{ Name = $null; Case = 'a $null name' }
)

# Act / Assert
foreach ($case in $badNames) {
    Assert-Throws `
        -ScriptBlock { & $module { Resolve-RequiredModule @args } -Module ([PSCustomObject]@{ Name = $case.Name }) } `
        -MessageLike "*is not a valid module name*" `
        -Message "$($case.Case) is refused as a module name"
}

Assert-Throws `
    -ScriptBlock {
        & $module { Resolve-RequiredModule @args } `
            -Module ([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = 'x' })
    } `
    -MessageLike "*'Pester'*invalid MinimumVersion 'x'*" `
    -Message 'A minimum version that is not a version is refused, naming the module'
Assert-Throws `
    -ScriptBlock {
        & $module { Resolve-RequiredModule @args } `
            -Module ([PSCustomObject]@{ Name = 'Pester'; MinimumVersion = 5.1 })
    } `
    -MessageLike "*'Pester'*MinimumVersion that is a Double*" `
    -Message 'and so is a number'

exit (Complete-TestRun)
