#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

# A disposable, uniquely-named variable -
# this test genuinely writes to the real User-scope environment,
# cleaned up at the end so repeated runs do not accumulate garbage there.
$varName = "TAFFARELJR_USERINPUT_TEST_$([guid]::NewGuid().ToString('N'))"

try {
    # Act
    Set-EnvironmentVariable -Name $varName -Value 'written'

    # Assert - the real .NET-level User-scope write
    # only actually lands on Windows
    # (confirmed: .NET 8+ makes this a documented no-op on Unix),
    # so this checks the real platform rather than assuming one
    if ($IsWindows) {
        Assert-Equal -Expected 'written' -Actual ([Environment]::GetEnvironmentVariable($varName, 'User')) -Message 'Writes to the User scope on Windows, so a later run can find it'
    }
    else {
        Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($varName, 'User')) -Message 'The User scope is a documented no-op on this platform'
    }
    Assert-Equal -Expected 'written' -Actual ([Environment]::GetEnvironmentVariable($varName)) -Message 'Also writes to the current process, so this run sees it without restarting'

    # Arrange / Act - the value can be piped in, with -Name given explicitly
    'piped-value' | Set-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected 'piped-value' -Actual ([Environment]::GetEnvironmentVariable($varName)) -Message 'The value binds from the pipeline'

    # Arrange - both branches below force $IsWindows
    # rather than relying on whichever platform happens to be running this file,
    # so the test is deterministic on Windows and on a Linux/macOS CI runner alike.
    # $IsWindows is read-only, so -Force is required,
    # and it is restored no matter what happens below.
    $originalIsWindows = $IsWindows
    try {
        # Arrange / Act - forced Windows: nothing extra prints
        Set-Variable -Name IsWindows -Value $true -Force -Scope Global
        $lines = Get-HostOutput { Set-EnvironmentVariable -Name $varName -Value 'written' }

        # Assert
        Assert-Equal -Expected 0 -Actual $lines.Count -Message 'On Windows, persistence is silent - no reminder is printed'

        # Arrange / Act - forced non-Windows: a reminder prints instead
        Set-Variable -Name IsWindows -Value $false -Force -Scope Global
        $lines = Get-HostOutput { Set-EnvironmentVariable -Name $varName -Value 'top-secret-value' }

        # Assert
        Assert-Equal -Expected 3 -Actual $lines.Count -Message 'On a non-Windows platform, a reminder prints instead of silently doing less'
        Assert-That -Condition ($lines -join "`n").Contains($varName) -Message 'The reminder names the variable to export'
        Assert-That -Condition (-not ($lines -join "`n").Contains('top-secret-value')) -Message 'The reminder never echoes the value itself, secret or not'
    }
    finally {
        Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
    }
}
finally {
    # Cleanup - remove both scopes this test touched
    [Environment]::SetEnvironmentVariable($varName, $null, 'User')
    [Environment]::SetEnvironmentVariable($varName, $null)
}

exit (Complete-TestRun)
