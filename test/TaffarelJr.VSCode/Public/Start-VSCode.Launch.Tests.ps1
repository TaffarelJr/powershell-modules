#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# The fake editor is a .cmd shim, which only Windows runs.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the fake editor launched end to end is a Windows .cmd shim')
}

# Every other module-level test replaces the launcher. This one launches for
# real, through the imported module, so a problem only the loaded module has
# cannot hide behind a fake. The fake editor is a batch file that records
# what it was given and exits at once.
$sandbox = New-VSCodeSandbox
$work = Join-Path $sandbox.Root 'work'
$repo = Join-Path $work 'my repo'
New-Item -ItemType Directory -Path $repo | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $install = Add-FakeVSCodeShim -Fixture $sandbox

    # Act
    Push-Location -LiteralPath $work
    try {
        Start-VSCode -Path 'my repo'
    }
    finally {
        Pop-Location
    }

    $ran = Wait-TestFile -Path $install.Received -TimeoutSeconds 60
    $located = Wait-TestFile -Path $install.WorkingDirectory -TimeoutSeconds 10

    # Assert
    Assert-That -Condition $ran -Message 'The fake editor really ran, launched by the imported module'
    Assert-Equal -Expected $repo -Actual ([File]::ReadAllText($install.Received).Trim()) `
        -Message 'and was given the path, resolved and whole'
    Assert-That -Condition $located -Message 'and recorded where it started'
    Assert-Equal -Expected $work -Actual ([File]::ReadAllText($install.WorkingDirectory).Trim()) `
        -Message 'which is PowerShell''s current location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same fake editor as a .bat file
    $batInstall = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code.bat'

    # Act
    Push-Location -LiteralPath $work
    try {
        Start-VSCode -Path 'my repo'
    }
    finally {
        Pop-Location
    }

    $batRan = Wait-TestFile -Path $batInstall.Received -TimeoutSeconds 60

    # Assert
    Assert-That -Condition $batRan -Message 'A .bat editor really runs, launched by the imported module'
    Assert-Equal -Expected $repo -Actual ([File]::ReadAllText($batInstall.Received).Trim()) `
        -Message 'and is given the path, resolved and whole'
}
finally {
    $leftovers = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'cmd.exe'" |
        Where-Object { $_.CommandLine -like "*$($sandbox.Root)*" }
    foreach ($process in $leftovers) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
