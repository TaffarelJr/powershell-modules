#Requires -Version 7.4
using namespace System.IO.Pipes

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Get-Module TaffarelJr.FileText

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'a named pipe opened by its path, as a file, is a Windows matter')
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a named pipe that hands over the bytes in two writes, a second
# apart, so a single read sees only the first two
$pipeName = "filetext-$([Guid]::NewGuid())"
$server = [NamedPipeServerStream]::new($pipeName, [PipeDirection]::Out, 1, [PipeTransmissionMode]::Byte)
$writer = [PowerShell]::Create()
$null = $writer.AddScript({
        param($Server)

        # Bounded, and the pipe closed whatever happens, so a reader that never
        # connects or never stops reading cannot keep this file waiting.
        try {
            $connected = $Server.WaitForConnectionAsync().Wait([TimeSpan]::FromSeconds(30))
            if ($connected) {
                $Server.Write([byte[]](0xEF, 0xBB), 0, 2)
                $Server.Flush()
                Start-Sleep -Seconds 1
                $Server.Write([byte[]](0xBF, 0x61), 0, 2)
                $Server.Flush()
            }
        }
        finally {
            $Server.Dispose()
        }
    }).AddArgument($server)
$writing = $writer.BeginInvoke()

# Act
try {
    $head = & $module { param($p) Read-FileHead -Path $p -Count 4 } "\\.\pipe\$pipeName"
}
finally {
    $server.Dispose()
    $null = $writing.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds(30))
    $writer.Dispose()
}

# Assert
Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF, 0x61)) -Actual $head `
    -Message 'A source that returns fewer bytes than asked for is read until the count is reached'

exit (Complete-TestRun)
