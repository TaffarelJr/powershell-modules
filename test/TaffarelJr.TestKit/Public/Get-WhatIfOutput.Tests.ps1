#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Reports a test result to the person at the console; it is not data.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets the session preferences the capture must not follow.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

$temp = [IO.Path]::GetTempPath()
$alphaLine = 'What if: Performing the operation "Set probe" on target "alpha".'
$betaLine = 'What if: Performing the operation "Set probe" on target "beta".'

function Set-Probe {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($PSCmdlet.ShouldProcess($Name, 'Set probe')) {
        "set $Name"
    }
}

function Get-CaptureFile {
    $files = Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Filter 'testkit-whatif-*.txt' -File
    return $files | Select-Object -ExpandProperty FullName
}

function Invoke-InPrivateTemp {
    param(
        [scriptblock]$ScriptBlock
    )

    $variables = 'TMP', 'TEMP', 'TMPDIR'
    $saved = @{}
    foreach ($variable in $variables) {
        $saved[$variable] = [Environment]::GetEnvironmentVariable($variable)
    }

    $folder = Join-Path ([IO.Path]::GetTempPath()) "testkit-private-$([Guid]::NewGuid())"
    $null = New-Item -ItemType Directory -Path $folder
    try {
        foreach ($variable in $variables) {
            [Environment]::SetEnvironmentVariable($variable, $folder)
        }

        & $ScriptBlock
    }
    finally {
        foreach ($variable in $variables) {
            [Environment]::SetEnvironmentVariable($variable, $saved[$variable])
        }

        Remove-Item -LiteralPath $folder -Recurse -Force
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$name = 'alpha'

# Act
$run = Get-WhatIfOutput { Set-Probe -Name $name -WhatIf }

# Assert
Assert-Equal -Expected @($alphaLine) -Actual $run.Messages `
    -Message 'A -WhatIf call in the block comes back as its What if: line, with the caller''s variables in reach'
Assert-Equal -Expected @() -Actual $run.Output -Message 'and nothing written to the pipeline is an empty Output'
Assert-That -Condition ($null -eq $run.Error) -Message 'and Error is $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$run = Get-WhatIfOutput {
    'before'
    Set-Probe -Name 'alpha' -WhatIf
    Write-Host 'printed, but no What if: line'
    Set-Probe -Name 'beta' -WhatIf
    Set-Probe -Name 'gamma'
    2
}

# Assert
Assert-Equal -Expected @($alphaLine, $betaLine) -Actual $run.Messages `
    -Message 'Each What if: line comes back in order, and no other host line'
Assert-Equal -Expected @('before', 'set gamma', 2) -Actual $run.Output `
    -Message 'and what the block wrote to the pipeline is Output, kept apart from the lines'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - lines that only resemble a message
$run = Get-WhatIfOutput {
    Write-Host 'what if: Performing the operation "Set probe" on target "alpha".'
    Write-Host 'WHAT IF: Performing the operation "Set probe" on target "beta".'
}

# Assert
Assert-Equal -Expected @() -Actual $run.Messages `
    -Message 'A line starting with the words in another casing is not a What if: message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$multiLine = 'What if: Performing the operation "Set probe" on target "first' + "`nsecond`nthird" + '".'

# Act - a target holding line breaks, between two ordinary messages and before other output
$run = Get-WhatIfOutput {
    Set-Probe -Name 'alpha' -WhatIf
    Set-Probe -Name "first`nsecond`nthird" -WhatIf
    Write-Host 'printed right after'
    Set-Probe -Name 'beta' -WhatIf
}

# Assert
Assert-Equal -Expected @($alphaLine, $multiLine, $betaLine) -Actual $run.Messages `
    -Message 'A message whose target holds line breaks comes back whole, and the lines around it are left out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$run = Get-WhatIfOutput { Set-Probe -Name 'alpha' }
$nothing = Get-WhatIfOutput { }

# Assert
Assert-Equal -Expected @() -Actual $run.Messages -Message 'A block that prints no What if: line has empty Messages'
Assert-Equal -Expected @('set alpha') -Actual $run.Output -Message 'while its pipeline output is still Output'
Assert-Equal -Expected @() -Actual $nothing.Messages -Message 'An empty block has empty Messages'
Assert-Equal -Expected @() -Actual $nothing.Output -Message 'and empty Output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$run = Get-WhatIfOutput { Set-Probe -Name 'alpha' -WhatIf }

# Assert
Assert-Equal -Expected @('Output', 'Messages', 'Error') -Actual @($run.PSObject.Properties.Name) `
    -Message 'The result has Output, Messages and Error, in that order'
Assert-That -Condition ($run.Messages -is [string[]]) -Message 'and Messages is an array of strings'
Assert-That -Condition ($run.Output -is [object[]]) -Message 'and Output is an array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a temp folder of this case's own, so a capture made by another run is never counted
$script:during = @()
$script:after = @()

# Act
Invoke-InPrivateTemp {
    $null = Get-WhatIfOutput {
        $script:during = @(Get-CaptureFile)
        Set-Probe -Name 'alpha' -WhatIf
    }
    $script:after = @(Get-CaptureFile)
}

# Assert
Assert-Equal -Expected 1 -Actual $script:during.Count -Message 'The block runs while a capture file of its own exists'
Assert-Equal -Expected 0 -Actual $script:after.Count -Message 'and the file is deleted afterwards'
Assert-Throws -ScriptBlock { Stop-Transcript } `
    -MessageLike '*not currently transcribing*' `
    -Message 'and no transcript is left running'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$script:during = @()
$script:after = @()
$throwing = {
    Invoke-InPrivateTemp {
        try {
            Get-WhatIfOutput {
                $script:during = @(Get-CaptureFile)
                Set-Probe -Name 'alpha' -WhatIf
                throw [IO.FileNotFoundException]::new('boom from the block')
            }
        }
        finally {
            $script:after = @(Get-CaptureFile)
        }
    }
}

# Act / Assert
Assert-Throws -ScriptBlock $throwing `
    -MessageLike 'boom from the block' `
    -ExceptionType ([IO.FileNotFoundException]) `
    -Message 'What a block throws reaches the caller, as it was thrown'

# Assert
Assert-Equal -Expected 1 -Actual $script:during.Count `
    -Message 'A block that throws also ran with a capture file of its own'
Assert-Equal -Expected 0 -Actual $script:after.Count -Message 'which is deleted all the same'
Assert-Throws -ScriptBlock { Stop-Transcript } `
    -MessageLike '*not currently transcribing*' `
    -Message 'and no transcript is left running after the throw'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$run = Get-WhatIfOutput -CaptureError {
    'partial'
    Set-Probe -Name 'alpha' -WhatIf
    throw 'boom from the block'
}

# Assert
Assert-That -Condition ($run.Error -is [System.Management.Automation.ErrorRecord]) `
    -Message 'With -CaptureError, what the block threw comes back as Error'
Assert-Equal -Expected 'boom from the block' -Actual $run.Error.Exception.Message -Message 'unchanged'
Assert-Equal -Expected @($alphaLine) -Actual $run.Messages -Message 'with the What if: lines printed before it'
Assert-Equal -Expected @('partial') -Actual $run.Output -Message 'and the output written before it'
Assert-Throws -ScriptBlock { Stop-Transcript } `
    -MessageLike '*not currently transcribing*' `
    -Message 'and no transcript is left running'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$run = Get-WhatIfOutput -CaptureError { Set-Probe -Name 'alpha' -WhatIf }

# Assert
Assert-That -Condition ($null -eq $run.Error) -Message 'With -CaptureError, a block that does not throw has Error $null'
Assert-Equal -Expected @($alphaLine) -Actual $run.Messages -Message 'and its lines as usual'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$outerPath = Join-Path $temp "testkit-outer-$([Guid]::NewGuid()).txt"
Start-Transcript -LiteralPath $outerPath -UseMinimalHeader | Out-Null

# Act
try {
    $run = Get-WhatIfOutput { Set-Probe -Name 'alpha' -WhatIf }
    $failed = Get-WhatIfOutput -CaptureError {
        Set-Probe -Name 'beta' -WhatIf
        throw 'boom from the block'
    }
}
finally {
    $stopped = "$(Stop-Transcript)"
}
$outerLines = @(Get-Content -LiteralPath $outerPath)
Remove-Item -LiteralPath $outerPath

# Assert
Assert-Equal -Expected @($alphaLine) -Actual $run.Messages `
    -Message 'A transcript already running does not get in the way of the capture'
Assert-Equal -Expected @($betaLine) -Actual $failed.Messages -Message 'nor of one whose block throws'
Assert-Equal -Expected "Transcript stopped, output file is $outerPath" -Actual $stopped `
    -Message 'and is still the one running afterwards, so only the capture''s own transcript was stopped'
Assert-That -Condition ($outerLines -contains $alphaLine -and $outerLines -contains $betaLine) `
    -Message 'and it records the What if: lines too'
Assert-Throws -ScriptBlock { Stop-Transcript } `
    -MessageLike '*not currently transcribing*' `
    -Message 'and nothing else was left running under it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$script:after = @()

# Act - the session itself previews every change
$run = Invoke-InPrivateTemp {
    $global:WhatIfPreference = $true
    try {
        Get-WhatIfOutput -CaptureError { Set-Probe -Name 'alpha' }
    }
    finally {
        $global:WhatIfPreference = $false
    }

    $script:after = @(Get-CaptureFile)
}

# Assert
Assert-That -Condition ($null -eq $run.Error) -Message 'A session set to preview does not stop the capture'
Assert-Equal -Expected @($alphaLine) -Actual $run.Messages `
    -Message 'and the block follows the session: its call prints a What if: line'
Assert-Equal -Expected @() -Actual $run.Output -Message 'and writes nothing'
Assert-Equal -Expected 0 -Actual $script:after.Count -Message 'and the capture file is still deleted'
Assert-Throws -ScriptBlock { Stop-Transcript } `
    -MessageLike '*not currently transcribing*' `
    -Message 'and no transcript is left running'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$script:after = @()

# Act - the session itself asks before every change
$run = Invoke-InPrivateTemp {
    $global:ConfirmPreference = 'Low'
    try {
        Get-WhatIfOutput -CaptureError { Set-Probe -Name 'alpha' -Confirm:$false }
    }
    finally {
        $global:ConfirmPreference = 'High'
    }

    $script:after = @(Get-CaptureFile)
}

# Assert
Assert-That -Condition ($null -eq $run.Error) -Message 'A session set to ask does not make the capture ask'
Assert-Equal -Expected @('set alpha') -Actual $run.Output -Message 'and the block runs as told'
Assert-Equal -Expected 0 -Actual $script:after.Count -Message 'and the capture file is deleted without asking'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Get-WhatIfOutput -ScriptBlock $null } `
    -MessageLike "*Cannot bind argument to parameter 'ScriptBlock' because it is null*" `
    -Message 'A $null block is refused'

exit (Complete-TestRun)
