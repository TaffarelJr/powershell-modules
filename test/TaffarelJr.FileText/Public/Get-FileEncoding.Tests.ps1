#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every kind of start a file can have, and what it should be read as
    $cases = @(
        @{ Name = 'no mark'; Bytes = [byte[]](0x68, 0x69); Type = 'UTF8Encoding'; Preamble = [byte[]]@() }
        @{
            Name = 'a UTF-8 mark'
            Bytes = [byte[]](0xEF, 0xBB, 0xBF, 0x68, 0x69)
            Type = 'UTF8Encoding'
            Preamble = [byte[]](0xEF, 0xBB, 0xBF)
        }
        @{
            Name = 'a UTF-16 little-endian mark'
            Bytes = [byte[]](0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00)
            Type = 'UnicodeEncoding'
            Preamble = [byte[]](0xFF, 0xFE)
        }
        @{
            Name = 'a UTF-16 big-endian mark'
            Bytes = [byte[]](0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69)
            Type = 'UnicodeEncoding'
            Preamble = [byte[]](0xFE, 0xFF)
        }
        @{
            Name = 'a UTF-32 little-endian mark'
            Bytes = [byte[]](0xFF, 0xFE, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00)
            Type = 'UTF32Encoding'
            Preamble = [byte[]](0xFF, 0xFE, 0x00, 0x00)
        }
        @{
            Name = 'a UTF-32 big-endian mark'
            Bytes = [byte[]](0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00, 0x68)
            Type = 'UTF32Encoding'
            Preamble = [byte[]](0x00, 0x00, 0xFE, 0xFF)
        }
        @{
            Name = 'a bare UTF-16 mark and nothing else'
            Bytes = [byte[]](0xFF, 0xFE)
            Type = 'UnicodeEncoding'
            Preamble = [byte[]](0xFF, 0xFE)
        }
        @{
            Name = 'a UTF-8 mark and nothing else'
            Bytes = [byte[]](0xEF, 0xBB, 0xBF)
            Type = 'UTF8Encoding'
            Preamble = [byte[]](0xEF, 0xBB, 0xBF)
        }
        @{
            Name = 'two NULs that are not a mark'
            Bytes = [byte[]](0x00, 0x00, 0x41)
            Type = 'UTF8Encoding'
            Preamble = [byte[]]@()
        }
        @{ Name = 'no bytes at all'; Bytes = [byte[]]@(); Type = 'UTF8Encoding'; Preamble = [byte[]]@() }
        @{
            Name = 'fewer bytes than any mark'
            Bytes = [byte[]](0x61, 0x62)
            Type = 'UTF8Encoding'
            Preamble = [byte[]]@()
        }
    )

    foreach ($case in $cases) {
        # Act
        $path = New-TestFile -Directory $sandbox -Name "$([Guid]::NewGuid()).txt" -Byte $case.Bytes
        $encoding = Get-FileEncoding -Path $path

        # Assert
        Assert-Equal -Expected $case.Type -Actual $encoding.GetType().Name `
            -Message "$($case.Name) is read as $($case.Type)"
        Assert-Equal -Expected $case.Preamble -Actual $encoding.GetPreamble() `
            -Message "$($case.Name) is written back with the same mark"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $plain = New-TestFile -Directory $sandbox -Name 'plain.txt' -Byte ([byte[]](0x68, 0x69))

    # Act
    $encoding = Get-FileEncoding -Path $plain

    # Assert
    Assert-Throws -ScriptBlock { $encoding.GetString([byte[]](0xE9)) } -MessageLike '*translate bytes*' `
        -Message 'The encoding refuses bytes it cannot map instead of substituting a character'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    $null = New-TestFile -Directory $here -Name 'f.txt' -Byte ([byte[]](0xEF, 0xBB, 0xBF, 0x68))
    $null = New-TestFile -Directory $there -Name 'f.txt' -Byte ([byte[]](0x68))

    # Act
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Get-FileEncoding -Path .\f.txt }

    # Assert
    Assert-Equal -Expected 3 -Actual $relative.GetPreamble().Length `
        -Message 'A relative path means the file in PowerShell''s location, not in the process''s working directory'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files listed by Get-ChildItem
    $piped = Join-Path $sandbox 'piped'
    New-Item -ItemType Directory -Path $piped | Out-Null
    $null = New-TestFile -Directory $piped -Name 'a.txt' -Byte ([byte[]](0xEF, 0xBB, 0xBF, 0x68))
    $null = New-TestFile -Directory $piped -Name 'b.txt' -Byte ([byte[]](0xFF, 0xFE, 0x68, 0x00))
    $listed = @(Get-ChildItem -LiteralPath $piped -File | Sort-Object Name)

    # Act
    $pipedEncodings = @($listed | Get-FileEncoding)

    # Assert
    Assert-Equal `
        -Expected @('utf-8', 'utf-16') `
        -Actual @($pipedEncodings.WebName) `
        -Message 'Files piped in each get their own encoding, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same files as path strings, a Get-Content list, and Resolve-Path output
    $list = Join-Path $sandbox 'list.txt'
    Set-Content -LiteralPath $list -Value $listed.FullName

    # Act
    $fromStrings = @($listed.FullName | Get-FileEncoding)
    $fromList = @(Get-Content -LiteralPath $list | Get-FileEncoding)
    $fromResolved = @(Resolve-Path -LiteralPath $listed.FullName | Get-FileEncoding)

    # Assert
    Assert-Equal -Expected @('utf-8', 'utf-16') -Actual @($fromStrings.WebName) `
        -Message 'Path strings piped in each get their own encoding'
    Assert-Equal -Expected @('utf-8', 'utf-16') -Actual @($fromList.WebName) `
        -Message 'and so do the lines of a file list'
    Assert-Equal -Expected @('utf-8', 'utf-16') -Actual @($fromResolved.WebName) `
        -Message 'and Resolve-Path output, by its Path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file that is not there, and a folder
    Assert-Throws -ScriptBlock { Get-FileEncoding -Path (Join-Path $sandbox 'nope.txt') } `
        -MessageLike "No such file: '*nope.txt'*" `
        -Message 'A missing file says so, naming it'
    Assert-Throws -ScriptBlock { Get-FileEncoding -Path $sandbox } -MessageLike '*is a folder, not a file*' `
        -Message 'A folder says it is a folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object that carries only a PSPath, and an item of a provider that is not the file system
    $env:FILETEXT_PIPEPROBE = 'C:\x'
    $withMark = New-TestFile -Directory $sandbox -Name 'pspath.txt' -Byte ([byte[]](0xEF, 0xBB, 0xBF, 0x68, 0x69))
    $psPathOnly = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$withMark" }

    # Act
    $fromPsPath = $psPathOnly | Get-FileEncoding
    $fromItem = Get-Item -LiteralPath $withMark | Get-FileEncoding
    $fromEnvItem = { Get-Item -LiteralPath 'Env:FILETEXT_PIPEPROBE' | Get-FileEncoding }

    # Assert
    Assert-Equal -Expected 'UTF8Encoding' -Actual $fromPsPath.GetType().Name `
        -Message 'An object with only a PSPath is bound by it, as a provider-qualified path'
    Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF)) -Actual $fromPsPath.GetPreamble() `
        -Message 'and the mark of that file is read'
    Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF)) -Actual $fromItem.GetPreamble() `
        -Message 'A file from Get-Item, which carries both a PSPath and a FullName, binds by one of them'
    Assert-Throws -ScriptBlock $fromEnvItem `
        -MessageLike "'*FILETEXT_PIPEPROBE*' is not a file system path*" `
        -Message 'An environment variable item is refused by its PSPath as not a file system path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a blank path
    Assert-Throws -ScriptBlock { Get-FileEncoding -Path '  ' } -MessageLike 'The path is blank*' `
        -Message 'A blank path is refused as blank, not taken to mean the current folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another program holds open
    $held = New-TestFile -Directory $sandbox -Name 'held.txt' -Byte ([byte[]](0x68, 0x69))
    $hold = Lock-TestFile -Path $held

    # Act / Assert
    try {
        Assert-Throws -ScriptBlock { Get-FileEncoding -Path $held } `
            -MessageLike ([WildcardPattern]::Escape("Cannot read '$held': ") + '*being used by another process*') `
            -Message 'A file held open by another program says it cannot read the file, and why'
    }
    finally {
        $hold.Dispose()
    }
}
finally {
    Remove-Item -LiteralPath 'Env:FILETEXT_PIPEPROBE' -ErrorAction Ignore
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
