#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a well-formed entry with both fields
$full = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
    MinimumVersion   = '5.0.0'
    DocumentationUrl = 'https://pester.dev'
}

# Assert
Assert-Equal -Expected 'Pester' -Actual $full.Name -Message 'Carries the given name'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $full.MinimumVersion -Message 'Converts MinimumVersion to a [Version]'
Assert-Equal -Expected 'https://pester.dev' -Actual $full.DocumentationUrl `
    -Message 'Carries the optional DocumentationUrl'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - DocumentationUrl is optional
$noUrl = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = '5.0.0' }
$emptyUrl = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
    MinimumVersion   = '5.0.0'
    DocumentationUrl = ''
}

# Assert
Assert-That -Condition ($null -eq $noUrl.DocumentationUrl) `
    -Message 'A missing DocumentationUrl reads as $null, not an error'
Assert-Equal -Expected '' -Actual $emptyUrl.DocumentationUrl `
    -Message 'An empty DocumentationUrl is kept as the empty string'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an ordered dictionary, and keys written in another case
$ordered = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry ([ordered]@{ MinimumVersion = '5.0.0' })
$lowercase = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
    minimumversion   = '5.0.0'
    documentationurl = 'https://pester.dev'
}

# Assert
Assert-Equal -Expected ([Version]'5.0.0') -Actual $ordered.MinimumVersion `
    -Message 'An [ordered] entry is accepted as a hashtable'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $lowercase.MinimumVersion `
    -Message 'Key names are matched without regard to case'
Assert-Equal -Expected 'https://pester.dev' -Actual $lowercase.DocumentationUrl `
    -Message 'DocumentationUrl is found without regard to case too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a MinimumVersion that is already a [Version]
$typed = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = [Version]'5.10' }

# Assert
Assert-Equal -Expected ([Version]'5.10') -Actual $typed.MinimumVersion `
    -Message 'A [Version] MinimumVersion is taken as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the names a module can have
foreach ($name in 'Az.Accounts', 'posh-git', 'PS_Read.Line', '7Zip4Powershell', 'a.b-c') {
    $entry = & $module { Get-RequiredModuleEntry @args } -Name $name -Entry @{ MinimumVersion = '1.0.0' }
    Assert-Equal -Expected $name -Actual $entry.Name -Message "'$name' is a valid module name"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - names that would match more than one module, or none,
# or that no package can have
$refusedNames = @(
    '', '*', 'Pes*', 'Pest?r', 'Pest[e]r', 'two words', 'a\b', 'a/b', "Pester`n"
    '.', '..', '-Force', '-', 'a..b', 'a.-b', '.Pester', 'Pester.', 'Pester-'
)

# Assert
foreach ($name in $refusedNames) {
    Assert-Throws -ScriptBlock {
        & $module { Get-RequiredModuleEntry @args } -Name $name -Entry @{ MinimumVersion = '5.0.0' }
    } -MessageLike '*is not a valid module name*' -Message "The name '$($name -replace "`n", '\n')' is refused"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the entry itself isn't a hashtable at all
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry '5.0.0'
} -MessageLike "*'Pester'*hashtable*String*" `
    -Message 'A non-hashtable entry throws, naming the module and the actual type'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the entry is $null
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry $null
} -MessageLike "*'Pester'*hashtable*" -Message 'A $null entry throws, naming the module'

#───────────────────────────────────────────────────────────────────────────────
# Act - MinimumVersion is missing entirely, with and without a documentation link
$linkOnly = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ DocumentationUrl = 'https://pester.dev' }
$nameOnly = & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{}

# Assert
Assert-That -Condition ($null -eq $linkOnly.MinimumVersion) `
    -Message 'An entry without a MinimumVersion has none, so any version of the module will do'
Assert-Equal -Expected 'https://pester.dev' -Actual $linkOnly.DocumentationUrl -Message 'and keeps its documentation link'
Assert-Equal -Expected 'Pester' -Actual $nameOnly.Name -Message 'An empty entry names the module'
Assert-That -Condition ($null -eq $nameOnly.MinimumVersion -and $null -eq $nameOnly.DocumentationUrl) `
    -Message 'and has neither a minimum version nor a link'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - MinimumVersion doesn't parse as a [Version]
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = 'not-a-version' }
} -MessageLike "*'Pester'*not-a-version*" `
    -Message 'An unparseable MinimumVersion throws, naming the module and the bad value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - MinimumVersion values that are not a plain version
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = $null }
} -MessageLike "*'Pester'*invalid MinimumVersion ''*" `
    -Message 'A $null MinimumVersion is refused instead of being taken as no minimum'

Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = '5' }
} -MessageLike "*invalid MinimumVersion '5'*" -Message 'A version of one part is refused'

Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = '5.0.0-beta1' }
} -MessageLike "*invalid MinimumVersion '5.0.0-beta1'*" -Message 'A prerelease label is refused'

Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = '1.2.3.4.5' }
} -MessageLike "*invalid MinimumVersion '1.2.3.4.5'*" -Message 'A version of five parts is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an unquoted MinimumVersion is a number, and a number
# loses its trailing zeros (5.10 is 5.1), so every number is refused, whole or not
$numbers = @(
    @{ Written = '5.0'; Value = 5.0; Type = 'Double' }
    @{ Written = '5.10'; Value = 5.10; Type = 'Double' }
    @{ Written = '1.05'; Value = 1.05; Type = 'Double' }
    @{ Written = '5'; Value = 5; Type = 'Int32' }
)

# Assert
foreach ($number in $numbers) {
    Assert-Throws -ScriptBlock {
        & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{ MinimumVersion = $number.Value }
    } -MessageLike "*'Pester'*MinimumVersion that is a $($number.Type)*quoted version*" `
        -Message "The unquoted number $($number.Written) is refused, with the hint to write the version as a string"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a key the module does not know, often a misspelling
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
        MinimumVersion  = '5.0.0'
        RequiredVersion = '5.1.0'
    }
} -MessageLike "*'Pester'*unknown key 'RequiredVersion'*MinimumVersion*DocumentationUrl*" `
    -Message 'An unknown key throws, naming the module, the key, and what is allowed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an unknown key named like a member of the
# dictionary that holds it, with an allowed key's name for a value
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
        MinimumVersion = '5.0.0'
        Keys           = 'MinimumVersion'
    }
} -MessageLike "*'Pester'*unknown key 'Keys'*MinimumVersion*DocumentationUrl*" `
    -Message 'An unknown key named Keys is refused, whatever its value says'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - DocumentationUrl that is not text
Assert-Throws -ScriptBlock {
    & $module { Get-RequiredModuleEntry @args } -Name 'Pester' -Entry @{
        MinimumVersion   = '5.0.0'
        DocumentationUrl = @{ Link = 'x' }
    }
} -MessageLike "*'Pester'*DocumentationUrl*not a string*" `
    -Message 'A DocumentationUrl that is not a string throws, naming the module'

exit (Complete-TestRun)
