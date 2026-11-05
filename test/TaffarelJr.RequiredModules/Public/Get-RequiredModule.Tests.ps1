#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest with a single entry
$sandbox = New-RequiredModulesSandbox
$singlePath = New-ManifestFile -Directory $sandbox -Name 'single.psd1' -Content @'
@{
    Pester = @{
        MinimumVersion   = '5.0.0'
        DocumentationUrl = 'https://pester.dev'
    }
}
'@

# Act
$single = @(Get-RequiredModule -Path $singlePath)

# Assert
Assert-Equal -Expected 1 -Actual $single.Count -Message 'One manifest entry returns one result'
Assert-Equal -Expected 'Pester' -Actual $single[0].Name -Message 'Reads the module name from the manifest key'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $single[0].MinimumVersion `
    -Message 'Reads and converts MinimumVersion to a [Version]'
Assert-Equal -Expected 'https://pester.dev' -Actual $single[0].DocumentationUrl `
    -Message 'Reads the optional DocumentationUrl'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest with entries written out of order, one missing the optional field
$multiPath = New-ManifestFile -Directory $sandbox -Name 'multi.psd1' -Content @'
@{
    PSReadLine = @{ MinimumVersion = '2.0.0'; DocumentationUrl = 'https://example.test' }
    Pester     = @{ MinimumVersion = '5.0.0' }
    Az         = @{ MinimumVersion = '9.0.0' }
}
'@

# Act
$multi = @(Get-RequiredModule -Path $multiPath)

# Assert
Assert-Equal -Expected 'Az, Pester, PSReadLine' -Actual ($multi.Name -join ', ') `
    -Message 'Entries come back in name order, whatever order the hashtable keeps them in'
Assert-That -Condition ($null -eq ($multi | Where-Object Name -EQ 'Pester').DocumentationUrl) `
    -Message 'A missing DocumentationUrl reads as $null, not an error'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a hashtable passed directly, with no .psd1 file at all
$direct = @(Get-RequiredModule -Data @{
        Pester = @{ MinimumVersion = '5.0.0'; DocumentationUrl = 'https://pester.dev' }
    })

# Assert
Assert-Equal -Expected 1 -Actual $direct.Count -Message 'A hashtable manifest is read the same as a file'
Assert-Equal -Expected 'Pester' -Actual $direct[0].Name `
    -Message 'A hashtable manifest reads the module name from its key'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $direct[0].MinimumVersion `
    -Message 'A hashtable manifest reads and converts MinimumVersion to a [Version]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an [ordered] dictionary of [ordered] entries
$ordered = @(Get-RequiredModule -Data ([ordered]@{
            Pester = [ordered]@{ MinimumVersion = '5.0.0' }
        }))

# Assert
Assert-Equal -Expected 'Pester' -Actual $ordered[0].Name -Message 'An [ordered] manifest is read like a hashtable'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a hashtable piped in instead of passed as -Data
$piped = @(@{ Pester = @{ MinimumVersion = '5.0.0' } } | Get-RequiredModule)

# Assert
Assert-Equal -Expected 1 -Actual $piped.Count -Message 'A piped hashtable manifest is read the same as -Data'
Assert-Equal -Expected 'Pester' -Actual $piped[0].Name `
    -Message 'A piped hashtable manifest reads the module name from its key'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - two hashtables piped in, one after the other
$pipedTwo = @(
    @{ Alpha = @{ MinimumVersion = '1.0.0' } },
    @{ Beta = @{ MinimumVersion = '2.0.0' } } | Get-RequiredModule
)

# Assert
Assert-Equal -Expected 'Alpha, Beta' -Actual ($pipedTwo.Name -join ', ') `
    -Message 'Every piped manifest is read, not just the last one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a path and a hashtable given by position
$positionalPath = @(Get-RequiredModule $singlePath)
$positionalData = @(Get-RequiredModule @{ Pester = @{ MinimumVersion = '5.0.0' } })

# Assert
Assert-Equal -Expected 'Pester' -Actual $positionalPath[0].Name -Message 'A path given by position is read as -Path'
Assert-Equal -Expected 'Pester' -Actual $positionalData[0].Name `
    -Message 'A hashtable given by position is read as -Data'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file piped in, and objects naming a file by Path or FullName
$fromFile = @(Get-Item -LiteralPath $singlePath | Get-RequiredModule)
$fromFiles = @(Get-Item -LiteralPath $singlePath, $multiPath | Get-RequiredModule)
$fromPathProperty = @([PSCustomObject]@{ Path = $singlePath } | Get-RequiredModule)

# Assert
Assert-Equal -Expected 'Pester' -Actual ($fromFile.Name -join ', ') -Message 'A piped file is read by its full name'
Assert-Equal -Expected 'Pester, Az, Pester, PSReadLine' -Actual ($fromFiles.Name -join ', ') `
    -Message 'Every piped file is read, one after another'
Assert-Equal -Expected 'Pester' -Actual ($fromPathProperty.Name -join ', ') `
    -Message 'A piped object with a Path property is read as -Path'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a hashtable manifest whose module names look like the
# properties a path is bound from
$lookalike = @(@{
        Path     = @{ MinimumVersion = '1.0.0' }
        FullName = @{ MinimumVersion = '2.0.0' }
    } | Get-RequiredModule)

# Assert
Assert-Equal -Expected 'FullName, Path' -Actual ($lookalike.Name -join ', ') `
    -Message 'A piped hashtable is always a manifest, even with keys named Path or FullName'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a manifest whose module names look like members of the
# dictionary that holds it
$memberNamed = @(Get-RequiredModule -Data @{
        Keys   = @{ MinimumVersion = '1.0.0' }
        Pester = @{ MinimumVersion = '5.0.0' }
    })

# Assert
Assert-Equal -Expected 'Keys, Pester' -Actual ($memberNamed.Name -join ', ') `
    -Message 'A module named Keys is read like any other'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a manifest with nothing in it
$emptyPath = New-ManifestFile -Directory $sandbox -Name 'empty.psd1' -Content '@{}'
$none = @(Get-RequiredModule -Path $emptyPath)

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'A manifest requiring nothing gives nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file whose name has wildcard characters, reached by a relative path
$bracketPath = New-ManifestFile -Directory $sandbox -Name 'req[1].psd1' `
    -Content "@{ Pester = @{ MinimumVersion = '5.0.0' } }"
$elsewhere = New-Item -ItemType Directory -Path (Join-Path $sandbox 'elsewhere')

# Act
$bracket = @(Get-RequiredModule -Path $bracketPath)
$relative = @(Use-SplitLocation -Location $sandbox -ProcessDirectory $elsewhere.FullName -ScriptBlock {
        Get-RequiredModule -Path '.\req[1].psd1'
    })

# Assert
Assert-Equal -Expected 'Pester' -Actual $bracket[0].Name `
    -Message 'A [ in the file name is part of the name, not a wildcard'
Assert-Equal -Expected 'Pester' -Actual $relative[0].Name `
    -Message 'A relative path means PowerShell''s location, not the process''s working directory'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path pointing at nothing fails clearly, not with
# whatever error Import-PowerShellDataFile happens to raise
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Path (Join-Path $sandbox 'nothing.psd1')
} -MessageLike '*not found*nothing.psd1*' -Message 'A missing -Path throws, naming the path'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path pointing at a folder is not a manifest either
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Path $sandbox
} -MessageLike '*not found*' -Message 'A folder as -Path throws the same clear message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files that are not a data file, each holding a secret
$secret = 'SENTINEL_SECRET_123'
$notData = "RequiredModules manifest '{0}' could not be read: it is not a PowerShell data file. " +
    'A data file holds one hashtable of literal values - no variables, commands, casts or operators - ' +
    'and has no syntax errors.'
$unreadable = [ordered]@{
    'array'  = "@('$secret', 'b')"
    'code'   = "@{ Pester = @{ MinimumVersion = (Get-Date) }; Secret = '$secret' }"
    'syntax' = "@{ Secret = '$secret'`r`n    Pester = @{ MinimumVersion = '5.0.0' }"
}

foreach ($kind in $unreadable.Keys) {
    $path = New-ManifestFile -Directory $sandbox -Name "$kind.psd1" -Content $unreadable[$kind]

    # Act
    $caught = $null
    try {
        $null = Get-RequiredModule -Path $path
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected ($notData -f $path) -Actual $caught.Exception.Message `
        -Message "A manifest file that is not a data file ($kind) throws, naming the file and the rule, not its text"
    Assert-Equal -Expected ($notData -f $path) -Actual $caught.TargetObject `
        -Message "and the target of that failure ($kind), which is its message, holds none of the file either"
    Assert-That -Condition (-not ($caught | Out-String).Contains($secret)) `
        -Message "and nothing that failure ($kind) shows holds the secret in the file"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an entry that isn't a hashtable at all
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Data @{ Pester = '5.0.0' }
} -MessageLike "*'Pester'*hashtable*" -Message 'A non-hashtable entry throws, naming the module and what was expected'

#───────────────────────────────────────────────────────────────────────────────
# Act - entries without a MinimumVersion
$unversioned = @(Get-RequiredModule -Data @{
        Pester     = @{ DocumentationUrl = 'https://pester.dev' }
        PSReadLine = @{}
    })

# Assert
Assert-Equal -Expected 'Pester, PSReadLine' -Actual ($unversioned.Name -join ', ') `
    -Message 'An entry without a MinimumVersion is read, in name order'
Assert-That -Condition ($null -eq $unversioned[0].MinimumVersion -and $null -eq $unversioned[1].MinimumVersion) `
    -Message 'and has no minimum version, so any version of the module will do'
Assert-Equal -Expected 'https://pester.dev' -Actual $unversioned[0].DocumentationUrl `
    -Message 'keeping its documentation link'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a MinimumVersion that isn't a valid version at all
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Data @{ Pester = @{ MinimumVersion = 'not-a-version' } }
} -MessageLike "*'Pester'*not-a-version*" `
    -Message 'An invalid MinimumVersion throws, naming the module and the bad value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a manifest key that is not a module name
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Data @{ 'Pes*' = @{ MinimumVersion = '5.0.0' } }
} -MessageLike "*'Pes*'*not a valid module name*" `
    -Message 'A wildcard as a module name throws instead of matching other modules'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path and -Data together is ambiguous, not a merge
Assert-Throws -ScriptBlock {
    Get-RequiredModule -Path $singlePath -Data @{}
} -ExceptionType ([System.Management.Automation.ParameterBindingException]) -Message '-Path and -Data together throws'

#───────────────────────────────────────────────────────────────────────────────
# Act - neither -Path nor -Data, where no one can be asked for the missing one
$neither = Get-NonInteractiveError -Module (Get-Module TaffarelJr.RequiredModules) -Command 'Get-RequiredModule' `
    -Directory $sandbox

# Assert
Assert-Equal -Expected 'ParameterBindingException' -Actual $neither.Type -Message 'Neither -Path nor -Data throws'
Assert-That -Condition ($neither.Message -like '*missing mandatory parameters: Data*') `
    -Message 'and says that the manifest, the default way of giving it, is what is missing'

# Cleanup

Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
