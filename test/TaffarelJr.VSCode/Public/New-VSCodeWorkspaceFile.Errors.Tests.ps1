#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) "vscode-workspace-errors-$([Guid]::NewGuid())"
$app = Join-Path $root 'app'
$lib = Join-Path $root 'lib'
New-Item -ItemType Directory -Path $app, $lib | Out-Null
$existing = Join-Path $root 'existing.code-workspace'
[File]::WriteAllText($existing, 'old')
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a workspace file that already exists, and no -Force
    $message = "The workspace file already exists (use -Force to overwrite it): $existing"

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act - a refusal whose caller asked for errors to be hidden
        $output = @()
        $caught = $null
        try {
            $output = @(New-VSCodeWorkspaceFile -Path $existing -Folder $app -ErrorAction $preference)
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($existing)) `
            -Message "Under -ErrorAction $preference a refusal still leaves the existing file as it was"
        Assert-Equal -Expected 0 -Actual $output.Count -Message 'and returns nothing'
        Assert-Equal -Expected 'RuntimeException,New-VSCodeWorkspaceFile' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the refusal is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $caught = $null
    try {
        $null = New-VSCodeWorkspaceFile -Path $existing -Folder $app
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,New-VSCodeWorkspaceFile' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A refusal raises a terminating error whose ID names the failure and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected $message -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert
    Assert-Throws -ScriptBlock { New-VSCodeWorkspaceFile -Path $existing -Folder $app -ErrorAction Stop } `
        -MessageLike '*already exists*' `
        -Message 'Under -ErrorAction Stop a refusal still throws'
    Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($existing)) `
        -Message 'and the existing file is left as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same folder piped in twice, which is refused when the pipeline ends
    $path = Join-Path $root 'twice.code-workspace'
    $duplicate = Get-Item -LiteralPath $app

    # Act
    $caught = $null
    try {
        $duplicate, $duplicate | New-VSCodeWorkspaceFile -Path $path -ErrorAction SilentlyContinue
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $path)) `
        -Message 'A folder given twice is refused, with errors hidden or not, and no file is written'
    Assert-Equal -Expected 'RuntimeException,New-VSCodeWorkspaceFile' -Actual $caught.FullyQualifiedErrorId `
        -Message 'as a terminating error'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
