#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

function New-TestTree {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
    New-Item -ItemType Directory -Path $root | Out-Null
    return $root
}

# --- happy path: content and names, across a nested tree, CRLF/BOM preserved ---
$root = New-TestTree
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'Placeholder.Sub') | Out-Null
    $filePath = Join-Path $root 'Placeholder.Sub' 'Placeholder.txt'
    [System.IO.File]::WriteAllText($filePath, "Hello Placeholder`r`n", [System.Text.UTF8Encoding]::new($true))

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 1 -Actual $result.FilesEdited -Message 'The one file containing the token is edited'
    Assert-Equal -Expected 2 -Actual $result.PathsRenamed -Message 'Both the directory and the file are renamed'
    $newPath = Join-Path $root 'Real.Sub' 'Real.txt'
    Assert-That -Condition (Test-Path -LiteralPath $newPath) -Message 'Both the directory and the file end up with the new name'
    Assert-Equal -Expected "Hello Real`r`n" -Actual ([System.IO.File]::ReadAllText($newPath)) -Message 'The content is rewritten too'
    $bytes = [System.IO.File]::ReadAllBytes($newPath)
    Assert-That -Condition ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -Message 'The BOM survives the whole operation'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a re-run after success is a true no-op ---
$root = New-TestTree
try {
    [System.IO.File]::WriteAllText((Join-Path $root 'Placeholder.txt'), 'Placeholder')
    $null = Rename-Token -Path $root -From 'Placeholder' -To 'Real'
    $second = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $second.FilesEdited -Message 'A re-run after success finds nothing left to edit'
    Assert-Equal -Expected 0 -Actual $second.PathsRenamed -Message 'A re-run after success finds nothing left to rename'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- -From equal to -To is a no-op ---
$root = New-TestTree
try {
    # Act
    $result = Rename-Token -Path $root -From 'Same' -To 'Same'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message '-From equal to -To is a no-op'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a case-only difference is real work, not a no-op (ordinal comparison) ---
$root = New-TestTree
try {
    [System.IO.File]::WriteAllText((Join-Path $root 'file.txt'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'placeholder'

    # Assert
    Assert-Equal -Expected 1 -Actual $result.FilesEdited -Message 'A case-only rename is real work, not treated as already done'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a missing folder throws ---
try {
    Rename-Token -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())) -From 'A' -To 'B'
    Assert-That -Condition $false -Message 'A missing folder throws (did not throw)'
}
catch {
    Assert-That -Condition $true -Message 'A missing folder throws'
}

# --- an illegal target name throws before anything changes ---
$root = New-TestTree
try {
    [System.IO.File]::WriteAllText((Join-Path $root 'file.txt'), 'Placeholder')
    $illegalChar = [System.IO.Path]::GetInvalidFileNameChars()[0]

    try {
        Rename-Token -Path $root -From 'Placeholder' -To "bad${illegalChar}name"
        Assert-That -Condition $false -Message 'An illegal target name throws (did not throw)'
    }
    catch {
        Assert-That -Condition $true -Message 'An illegal target name throws'
    }

    # Assert
    Assert-Equal -Expected 'Placeholder' -Actual ([System.IO.File]::ReadAllText((Join-Path $root 'file.txt'))) -Message 'Nothing was changed before the illegal name was caught'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a target containing the source throws, since a re-run would not be safe ---
$root = New-TestTree
try {
    try {
        Rename-Token -Path $root -From 'Placeholder' -To 'PlaceholderLib'
        Assert-That -Condition $false -Message 'A target containing the source throws (did not throw)'
    }
    catch {
        Assert-That -Condition $true -Message 'A target containing the source throws, since a re-run would rename it again'
    }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- an excluded directory is left completely untouched ---
$root = New-TestTree
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'bin') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $root 'bin' 'Placeholder.txt'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'Content under an excluded directory is not edited'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $root 'bin' 'Placeholder.txt')) -Message 'A file under an excluded directory keeps its original name'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a skip-extension file is renamed but its content is left untouched ---
$root = New-TestTree
try {
    [System.IO.File]::WriteAllText((Join-Path $root 'Placeholder.png'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'A skip-extension file has its content left alone'
    Assert-Equal -Expected 1 -Actual $result.PathsRenamed -Message 'A skip-extension file is still renamed'
    Assert-Equal -Expected 'Placeholder' -Actual ([System.IO.File]::ReadAllText((Join-Path $root 'Real.png'))) -Message 'The skip-extension file keeps its original content'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- binary content holding the token (an unlisted extension) is skipped with a warning, not corrupted ---
$root = New-TestTree
try {
    $binaryPath = Join-Path $root 'Placeholder.dat'
    [System.IO.File]::WriteAllBytes($binaryPath, [byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00))
    $originalBytes = [System.IO.File]::ReadAllBytes($binaryPath)

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'Binary content is not counted as edited'
    Assert-That -Condition ($result.Warning.Count -ge 1) -Message 'Skipping binary content is reported in Warning'
    $newPath = Join-Path $root 'Real.dat'
    Assert-That -Condition (Test-Path -LiteralPath $newPath) -Message 'The name pass still renames the file, independent of its content'
    Assert-Equal -Expected $originalBytes -Actual ([System.IO.File]::ReadAllBytes($newPath)) -Message 'Binary content survives byte-for-byte despite the file being renamed'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- a rename collision throws, naming both paths, after the rest of the tree is still processed ---
$root = New-TestTree
try {
    [System.IO.File]::WriteAllText((Join-Path $root 'Placeholder.txt'), 'Placeholder')
    [System.IO.File]::WriteAllText((Join-Path $root 'Real.txt'), 'already here')
    [System.IO.File]::WriteAllText((Join-Path $root 'OtherPlaceholder.txt'), 'Placeholder')

    try {
        Rename-Token -Path $root -From 'Placeholder' -To 'Real'
        Assert-That -Condition $false -Message 'A rename collision throws (did not throw)'
    }
    catch {
        Assert-That -Condition ($_.Exception.Message -like '*Placeholder.txt*') -Message 'The error names the source of the collision'
        Assert-That -Condition ($_.Exception.Message -like '*Real.txt*') -Message 'The error names the target of the collision'
    }

    # Assert
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $root 'OtherReal.txt')) -Message 'An unrelated item still gets renamed despite the other collision'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
