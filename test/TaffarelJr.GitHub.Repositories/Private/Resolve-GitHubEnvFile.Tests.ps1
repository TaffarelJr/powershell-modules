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

$resolve = {
    param($Path)

    Resolve-GitHubEnvFile -Path $Path
}

$folder = Join-Path ([IO.Path]::GetTempPath()) "envfile-$([Guid]::NewGuid())"
$elsewhere = Join-Path $folder 'elsewhere'
New-Item -ItemType Directory -Path $elsewhere | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $folder 'plain.env'), "A=1`n", $utf8)
[IO.File]::WriteAllBytes((Join-Path $folder 'bom.env'), [byte[]](0xEF, 0xBB, 0xBF) + $utf8.GetBytes("A=1`n"))
[IO.File]::WriteAllBytes((Join-Path $folder 'short.env'), [byte[]](0xEF, 0xBB))
[IO.File]::WriteAllBytes((Join-Path $folder 'empty.env'), [byte[]]@())
[IO.File]::WriteAllText((Join-Path $folder 'utf16le.env'), "A=1`n", [Text.UnicodeEncoding]::new($false, $true))
[IO.File]::WriteAllText((Join-Path $folder 'utf16be.env'), "A=1`n", [Text.UnicodeEncoding]::new($true, $true))
[IO.File]::WriteAllBytes((Join-Path $folder 'lone-ff.env'), [byte[]](0xFF))
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act - files given by a relative path, with the process in another folder
    $resolved = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        @(
            & $module $resolve 'plain.env'
            & $module $resolve 'short.env'
            & $module $resolve 'empty.env'
            & $module $resolve 'lone-ff.env'
        )
    }

    # Assert
    Assert-Equal -Expected @(
        (Join-Path $folder 'plain.env')
        (Join-Path $folder 'short.env')
        (Join-Path $folder 'empty.env')
        (Join-Path $folder 'lone-ff.env')
    ) -Actual $resolved `
        -Message 'A file is resolved from PowerShell''s location, and one too short to hold a byte-order mark is fine'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file starting with a UTF-8 byte-order mark
    Assert-Throws -ScriptBlock {
        & $module $resolve (Join-Path $folder 'bom.env')
    } -MessageLike "-EnvFile '$(Join-Path $folder 'bom.env')' starts with a UTF-8 byte-order mark, which gh reads as part of the first name: save the file without one." `
        -Message 'A byte-order mark is refused before gh would misread it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-16 files, little- and big-endian, which gh cannot read
    $utf16 = 'starts with a UTF-16 byte-order mark, and gh reads only UTF-8: save the file as UTF-8 without a byte-order mark.'

    # Act / Assert
    foreach ($name in 'utf16le.env', 'utf16be.env') {
        Assert-Throws -ScriptBlock {
            & $module $resolve (Join-Path $folder $name)
        } -MessageLike "-EnvFile '$(Join-Path $folder $name)' $utf16" `
            -Message "A UTF-16 file ($name) is refused, saying to save it as UTF-8"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - paths that are no file
    Assert-Throws -ScriptBlock {
        & $module $resolve (Join-Path $folder 'missing.env')
    } -MessageLike "-EnvFile '*missing.env' is not a file." `
        -Message 'A missing file is refused through Core, naming -EnvFile'
    Assert-Throws -ScriptBlock {
        & $module $resolve '-'
    } -MessageLike "-EnvFile '-' would make gh read standard input: give the path of a file." `
        -Message 'as is a lone dash'
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
