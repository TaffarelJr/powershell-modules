#Requires -Version 7.4
using namespace System.IO
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets the session preferences the code under test must not follow.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$root = Join-Path ([Path]::GetTempPath()) "vscode-workspace-whatif-$([Guid]::NewGuid())"
$app = Join-Path $root 'app'
$lib = Join-Path $root 'lib'
New-Item -ItemType Directory -Path $app, $lib | Out-Null
$mirror = New-SettingsFolder -Root $root -Name 'mirror' -Content '{ "editor.tabSize": 2 }'
$existing = Join-Path $root 'existing.code-workspace'
[File]::WriteAllText($existing, 'old')
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = Join-Path $root 'new.code-workspace'

    # Act
    $run = Get-WhatIfOutput { New-VSCodeWorkspaceFile -Path $path -Folder $app -WhatIf }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $path)) -Message '-WhatIf creates no workspace file'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not the path'
    Assert-Equal -Expected @("What if: Performing the operation ""Write workspace file"" on target ""$path"".") `
        -Actual $run.Messages -Message '-WhatIf names the file it would write'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two folders from the pipeline, overwriting with every option
    $folders = @(Get-Item -LiteralPath $app, $lib)
    $options = @{
        Path               = $existing
        Setting            = @{ 'editor.rulers' = @(80) }
        Extension          = 'ms-vscode.powershell'
        Comment            = 'A note'
        MirrorSettingsFrom = $mirror
        Force              = $true
    }

    # Act
    $run = Get-WhatIfOutput { $folders | New-VSCodeWorkspaceFile @options -WhatIf }

    # Assert
    Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($existing)) `
        -Message '-WhatIf with -Force and every other option leaves an existing file as it was'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Write workspace file"" on target ""$existing"".") `
        -Actual $run.Messages -Message 'and names the file it would overwrite, once for all the piped folders'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { New-VSCodeWorkspaceFile -Path $existing -Folder $app -WhatIf } `
        -MessageLike 'The workspace file already exists (use -Force to overwrite it):*' `
        -Message '-WhatIf still refuses to overwrite without -Force'
    $twice = Join-Path $root 'twice.code-workspace'
    Assert-Throws -ScriptBlock { New-VSCodeWorkspaceFile -Path $twice -Folder $app, $app -WhatIf } `
        -MessageLike 'The same workspace folder is given twice:*' `
        -Message 'and still refuses a folder given twice'
    Assert-Equal -Expected 'old' -Actual ([File]::ReadAllText($existing)) -Message 'and changes nothing doing so'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the session itself previews every change
    $previewed = Join-Path $root 'previewed.code-workspace'
    $global:WhatIfPreference = $true
    try {
        # Act
        $result = New-VSCodeWorkspaceFile -Path $previewed -Folder $app -WhatIf:$false

        # Assert
        Assert-That -Condition (Test-Path -LiteralPath $previewed) `
            -Message '-WhatIf:$false writes the file even when the session previews: Write-TextFile is told so too'
        Assert-Equal -Expected $previewed -Actual $result -Message 'and returns its path'
    }
    finally {
        $global:WhatIfPreference = $false
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the session itself asks before every change, where nobody
    # can answer
    $unasked = Join-Path $root 'unasked.code-workspace'
    $global:ConfirmPreference = 'Low'
    try {
        # Act
        $run = Get-WhatIfOutput -CaptureError { New-VSCodeWorkspaceFile -Path $unasked -Folder $app -Confirm:$false }

        # Assert
        Assert-Equal -Expected $null -Actual $run.Error `
            -Message '-Confirm:$false asks nothing even when the session asks: Write-TextFile is told so too'
        Assert-That -Condition (Test-Path -LiteralPath $unasked) -Message 'and the file is written'
        Assert-Equal -Expected @($unasked) -Actual $run.Output -Message 'and its path returned'
    }
    finally {
        $global:ConfirmPreference = 'High'
    }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
