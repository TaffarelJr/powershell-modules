#Requires -Version 7.4
using namespace System.Management.Automation.Language

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'The sample commands are only inspected with Get-Command, never run.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseProcessBlockForPipelineCommand',
    '',
    Justification = 'The sample commands are only inspected with Get-Command, never run.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseConsistentParameterSetName',
    '',
    Justification = 'The sample commands that name no default parameter set are the cases under test.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot 'PublicSurfaceTestHelper.ps1')

$raise = '$PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ ' +
    '-Command $MyInvocation.MyCommand.Name))'
$boundary = "try { Invoke-Work } catch { $raise }"
$readmeUri = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Sample/README.md'
$changelogUri = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Sample/CHANGELOG.md'
$noCatch = 'has no catch that calls ThrowTerminatingError with ConvertTo-CommandError'

function Get-SampleScript {
    <#
    .SYNOPSIS
        Parses script text, for a detector to read.
    #>
    [CmdletBinding()]
    [OutputType([ScriptBlockAst])]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $tokens = $null
    $parseErrors = $null
    return [Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)
}

function Get-SampleFunction {
    <#
    .SYNOPSIS
        Parses a function's text, with <boundary> and <raise> filled in, and
        returns its definition.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $filled = $Text.Replace('<boundary>', $boundary).Replace('<raise>', $raise)
    return (Get-SampleScript -Text $filled).EndBlock.Statements[0]
}

function Get-HelpSampleFunction {
    <#
    .SYNOPSIS
        Returns the definition of Test-Sample, whose help holds a synopsis
        and the given lines, and whose param block carries the attributes.
    .PARAMETER Help
        Help lines, a ~ between two of them standing for a line break.
    .PARAMETER Attributes
        Attributes to put before param, on one line.
    #>
    [CmdletBinding()]
    param(
        [string]$Help = '',

        [string]$Attributes = ''
    )

    $lines = @($Help -split '~' | ForEach-Object { "    $_" })
    $text = "function Test-Sample {`n    <#`n    .SYNOPSIS`n        Does a thing.`n" +
        "$($lines -join "`n")`n    #>`n    [CmdletBinding()]`n    $Attributes`n" +
        "    param([string]`$Name)`n    process { Invoke-Work }`n}"
    return (Get-SampleScript -Text $text).EndBlock.Statements[0]
}

function New-SampleModule {
    <#
    .SYNOPSIS
        Writes a module of one empty script file into a folder of its own,
        and returns the path of its manifest.
    .PARAMETER Root
        The folder that holds one folder per module.
    .PARAMETER Name
        The module's name.
    .PARAMETER RootModule
        The script file the manifest names as the module's.
    .PARAMETER Extra
        Manifest entries to add, each after a semicolon.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$RootModule = "$Name.psm1",

        [string]$Extra = ''
    )

    $folder = Join-Path $Root $Name
    $null = New-Item -ItemType Directory -Path $folder
    Set-Content -LiteralPath (Join-Path $folder "$Name.psm1") -Value '# nothing'
    $manifestPath = Join-Path $folder "$Name.psd1"
    $manifest = "@{ RootModule = '$RootModule'; ModuleVersion = '0.1.0'; GUID = '$([Guid]::NewGuid())'$Extra }"
    Set-Content -LiteralPath $manifestPath -Value $manifest
    return $manifestPath
}
function Test-SampleOneSet {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'A')]
        $One,

        $Two
    )
}

function Test-SampleNoSet {
    [CmdletBinding()]
    param($One)
}

function Test-SampleSetPairDefault {
    [CmdletBinding(DefaultParameterSetName = 'A')]
    param(
        [Parameter(ParameterSetName = 'A')]
        $One,

        [Parameter(ParameterSetName = 'B')]
        $Two
    )
}

function Test-SampleSetPair {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'A')]
        $One,

        [Parameter(ParameterSetName = 'B')]
        $Two
    )
}

function Test-SampleSetTriple {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'A')]
        $One,

        [Parameter(ParameterSetName = 'B')]
        $Two,

        [Parameter(ParameterSetName = 'C')]
        $Three
    )
}

function Test-SamplePathAliased {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [string]$Path
    )
}

function Test-SamplePathPlain {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Path
    )
}

function Test-SampleLiteralPathPlain {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$LiteralPath
    )
}

function Test-SampleBothPlain {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$LiteralPath
    )
}

function Test-SamplePathByValue {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
}

function Test-SamplePathNotPiped {
    [CmdletBinding()]
    param([string]$Path)
}

function Test-SampleOtherName {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$FilePath
    )
}

function Test-SamplePathOtherAlias {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('P')]
        [string]$Path
    )
}

function Test-SamplePathSetPair {
    [CmdletBinding(DefaultParameterSetName = 'A')]
    param(
        [Parameter(ParameterSetName = 'A')]
        [Parameter(ParameterSetName = 'B', ValueFromPipelineByPropertyName)]
        [string]$Path
    )
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$boundaryCases = @(
    @{
        Name     = 'A process block that is one try whose catch raises through the converter has no problem'
        Text     = 'function Test-Sample { param() process { <boundary> } }'
        Expected = @()
    }
    @{
        Name     = 'and so do a begin, a process and an end block that each are'
        Text     = 'function Test-Sample { param() begin { <boundary> } process { <boundary> } end { <boundary> } }'
        Expected = @()
    }
    @{
        Name     = 'and so does a function with no named block whose whole body is one'
        Text     = 'function Test-Sample { [CmdletBinding()] param() <boundary> }'
        Expected = @()
    }
    @{
        Name     = 'and so does one that is not advanced and has no param block'
        Text     = 'function Test-Sample { <boundary> }'
        Expected = @()
    }
    @{
        Name     = 'A try with another catch before the raising one, and a finally, has no problem'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch [System.IO.IOException] { throw } ' +
        'catch { <raise> } finally { Clean-Up } } }'
        Expected = @()
    }
    @{
        Name     = 'and a raise nested deeper in the catch has none'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch { if ($true) { <raise> } } } }'
        Expected = @()
    }
    @{
        Name     = 'and a lower-case psCmdlet and converter name has none'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch ' +
        '{ $pscmdlet.throwterminatingerror((convertto-commanderror -ErrorRecord $_ -Command x)) } } }'
        Expected = @()
    }
    @{
        Name     = 'A clean block is not part of the boundary'
        Text     = 'function Test-Sample { param() process { <boundary> } clean { Remove-Thing } }'
        Expected = @()
    }
    @{
        Name     = 'A function with a param block and nothing else has an empty body'
        Text     = 'function Test-Sample { param() }'
        Expected = @('Test-Sample body is empty, so it has no error boundary')
    }
    @{
        Name     = 'and so has one with no statement and no param block'
        Text     = 'function Test-Sample { }'
        Expected = @('Test-Sample body is empty, so it has no error boundary')
    }
    @{
        Name     = 'An empty named block is reported by its name'
        Text     = 'function Test-Sample { param() process { } }'
        Expected = @('Test-Sample process block is empty, so it has no error boundary')
    }
    @{
        Name     = 'A body that is one plain statement is not a try'
        Text     = 'function Test-Sample { param() Invoke-Work }'
        Expected = @('Test-Sample body is not exactly one try statement')
    }
    @{
        Name     = 'A try after another statement is not alone'
        Text     = 'function Test-Sample { param() process { $x = 1 ; <boundary> } }'
        Expected = @('Test-Sample process block is not exactly one try statement')
    }
    @{
        Name     = 'A try followed by another statement is not alone'
        Text     = 'function Test-Sample { param() end { <boundary> ; $x = 1 } }'
        Expected = @('Test-Sample end block is not exactly one try statement')
    }
    @{
        Name     = 'A try with only a finally has no catch to raise'
        Text     = 'function Test-Sample { param() process { try { Invoke-Work } finally { Clean-Up } } }'
        Expected = @("Test-Sample process block $noCatch")
    }
    @{
        Name     = 'A catch that only rethrows does not raise through the converter'
        Text     = 'function Test-Sample { param() process { try { Invoke-Work } catch { throw } } }'
        Expected = @("Test-Sample process block $noCatch")
    }
    @{
        Name     = 'A ThrowTerminatingError of the plain error record is not enough'
        Text     = 'function Test-Sample { param() begin { try { Invoke-Work } catch ' +
        '{ $PSCmdlet.ThrowTerminatingError($_) } } }'
        Expected = @("Test-Sample begin block $noCatch")
    }
    @{
        Name     = 'and so is a converted record handed over through a variable'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch ' +
        '{ $e = ConvertTo-CommandError -ErrorRecord $_ -Command x ; $PSCmdlet.ThrowTerminatingError($e) } } }'
        Expected = @("Test-Sample end block $noCatch")
    }
    @{
        Name     = 'and so is a ThrowTerminatingError on anything but $PSCmdlet'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch ' +
        '{ $other.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command x)) } } }'
        Expected = @("Test-Sample end block $noCatch")
    }
    @{
        Name     = 'and so is another $PSCmdlet method given the converted record'
        Text     = 'function Test-Sample { param() end { try { Invoke-Work } catch ' +
        '{ $PSCmdlet.WriteError((ConvertTo-CommandError -ErrorRecord $_ -Command x)) } } }'
        Expected = @("Test-Sample end block $noCatch")
    }
    @{
        Name     = 'A function with only a dynamicparam block has no block to hold one'
        Text     = 'function Test-Sample { dynamicparam { } }'
        Expected = @('Test-Sample has no begin, process or end block to hold the error boundary')
    }
    @{
        Name     = 'A function with one good block and one bad one is reported for the bad one only'
        Text     = 'function Test-Sample { param() begin { <boundary> } process { Invoke-Work } end { <boundary> } }'
        Expected = @('Test-Sample process block is not exactly one try statement')
    }
    @{
        Name     = 'Every bad block is reported, begin before process before end'
        Text     = 'function Test-Sample { param() begin { } process { Invoke-Work } ' +
        'end { try { Invoke-Work } finally { } } }'
        Expected = @(
            'Test-Sample begin block is empty, so it has no error boundary'
            'Test-Sample process block is not exactly one try statement'
            "Test-Sample end block $noCatch"
        )
    }
)

# Act / Assert
foreach ($case in $boundaryCases) {
    $function = Get-SampleFunction -Text $case.Text
    Assert-Equal -Expected $case.Expected -Actual @(Get-ErrorBoundaryProblem -Function $function) `
        -Message "Get-ErrorBoundaryProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what each function does first in its first block
$pin = '$ErrorActionPreference = ''Stop'''
$pinMessage = 'does not begin its try with $ErrorActionPreference = ''Stop'', ' +
    'so -ErrorAction SilentlyContinue would hide a failure'
$preferenceCases = @(
    @{
        Name     = 'A function that begins its try with the pin has no problem'
        Text     = "function Test-Sample { param() process { try { $pin ; Invoke-Work } catch { <raise> } } }"
        Expected = @()
    }
    @{
        Name     = 'and so does one with no named block'
        Text     = "function Test-Sample { param() try { $pin ; Invoke-Work } catch { <raise> } }"
        Expected = @()
    }
    @{
        Name     = 'and one with begin, process and end, pinned once, in begin'
        Text     = "function Test-Sample { param() begin { try { $pin } catch { <raise> } } " +
        'process { <boundary> } end { <boundary> } }'
        Expected = @()
    }
    @{
        Name     = 'and a pin written with double quotes'
        Text     = 'function Test-Sample { param() end { try { $ErrorActionPreference = "Stop" ; Invoke-Work } ' +
        'catch { <raise> } } }'
        Expected = @()
    }
    @{
        Name     = 'A try that does not pin is reported'
        Text     = 'function Test-Sample { param() process { <boundary> } }'
        Expected = @("Test-Sample $pinMessage")
    }
    @{
        Name     = 'and so is a pin that is not the first statement of the try'
        Text     = "function Test-Sample { param() process { try { Invoke-Work ; $pin } catch { <raise> } } }"
        Expected = @("Test-Sample $pinMessage")
    }
    @{
        Name     = 'and a pin to another value'
        Text     = 'function Test-Sample { param() process { try { $ErrorActionPreference = ''Continue'' ; ' +
        'Invoke-Work } catch { <raise> } } }'
        Expected = @("Test-Sample $pinMessage")
    }
    @{
        Name     = 'and a pin of another variable'
        Text     = 'function Test-Sample { param() process { try { $VerbosePreference = ''Stop'' ; Invoke-Work } ' +
        'catch { <raise> } } }'
        Expected = @("Test-Sample $pinMessage")
    }
    @{
        Name     = 'and a pin in process when begin comes first, since begin is the first block'
        Text     = 'function Test-Sample { param() begin { <boundary> } ' +
        "process { try { $pin } catch { <raise> } } }"
        Expected = @("Test-Sample $pinMessage")
    }
    @{
        Name     = 'A first block that is not a try has nowhere to pin it'
        Text     = 'function Test-Sample { param() process { Invoke-Work } }'
        Expected = @('Test-Sample does not start with a try statement to pin the error preference in')
    }
    @{
        Name     = 'A function with only a dynamicparam block has no block to pin it in'
        Text     = 'function Test-Sample { dynamicparam { } }'
        Expected = @('Test-Sample has no block to pin the error preference in')
    }
)

# Act / Assert
foreach ($case in $preferenceCases) {
    $function = Get-SampleFunction -Text $case.Text
    Assert-Equal -Expected $case.Expected -Actual @(Get-ErrorPreferenceProblem -Function $function) `
        -Message "Get-ErrorPreferenceProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - functions that support -WhatIf, with and without the copies of a caller's preferences
$pinLine = '$ErrorActionPreference = ''Stop'''
$whatIfCopy = "if (-not `$PSBoundParameters.ContainsKey('WhatIf')) {`n" +
    "    `$WhatIfPreference = `$PSCmdlet.GetVariableValue('WhatIfPreference')`n}"
$confirmCopy = "if (-not `$PSBoundParameters.ContainsKey('Confirm')) {`n" +
    "    `$ConfirmPreference = `$PSCmdlet.GetVariableValue('ConfirmPreference')`n}"
$bareCopy = '$WhatIfPreference = $PSCmdlet.GetVariableValue(''WhatIfPreference'')'
$whatIfMissing = "Test-Sample does not copy a caller's WhatIfPreference after its pin: " +
    'a function invoked with -WhatIf that calls it would still change things'
$confirmMissing = "Test-Sample does not copy a caller's ConfirmPreference after its pin: " +
    'a function invoked with -Confirm that calls it would not be asked'
$supportsText = {
    param([string[]]$Statements, [string]$Binding = '[CmdletBinding(SupportsShouldProcess)]')
    "function Test-Sample {`n    $Binding`n    param()`n    process {`n        try {`n" +
    (($Statements | ForEach-Object { "            $_" }) -join "`n") +
    "`n        }`n        catch {`n            <raise>`n        }`n    }`n}"
}
$whatIfCases = @(
    @{
        Name     = 'Both copies after the pin pass'
        Text     = & $supportsText @($pinLine, $whatIfCopy, $confirmCopy, 'Invoke-Work')
        Expected = @()
    }
    @{
        Name     = 'A function without SupportsShouldProcess needs no copy'
        Text     = & $supportsText @($pinLine, 'Invoke-Work') '[CmdletBinding()]'
        Expected = @()
    }
    @{
        Name     = 'A missing WhatIf copy is named'
        Text     = & $supportsText @($pinLine, $confirmCopy, 'Invoke-Work')
        Expected = @($whatIfMissing)
    }
    @{
        Name     = 'A missing Confirm copy is named'
        Text     = & $supportsText @($pinLine, $whatIfCopy, 'Invoke-Work')
        Expected = @($confirmMissing)
    }
    @{
        Name     = 'A copy without its guard does not count'
        Text     = & $supportsText @($pinLine, $bareCopy, $confirmCopy, 'Invoke-Work')
        Expected = @($whatIfMissing)
    }
    @{
        Name     = 'Neither copy is named twice'
        Text     = & $supportsText @($pinLine, 'Invoke-Work')
        Expected = @($whatIfMissing, $confirmMissing)
    }
    @{
        Name     = 'A function with no try is left to the pin check'
        Text     = 'function Test-Sample { [CmdletBinding(SupportsShouldProcess)] param() process { Invoke-Work } }'
        Expected = @()
    }
)

# Act / Assert
foreach ($case in $whatIfCases) {
    $function = Get-SampleFunction -Text $case.Text
    Assert-Equal -Expected $case.Expected -Actual @(Get-PreferenceCopyProblem -Function $function) `
        -Message "Get-PreferenceCopyProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - functions that write verbose output or run a tool, with and without the Verbose copy
$verboseCopy = "if (-not `$PSBoundParameters.ContainsKey('Verbose')) {`n" +
    "    `$VerbosePreference = `$PSCmdlet.GetVariableValue('VerbosePreference')`n}"
$verboseMissing = "Test-Sample does not copy a caller's VerbosePreference after its pin: " +
    'a function invoked with -Verbose that calls it would print no verbose line'
$verboseCases = @(
    @{
        Name     = 'A function that writes verbose output with the copy passes'
        Text     = & $supportsText @($pinLine, $verboseCopy, 'Write-Verbose ''x''') '[CmdletBinding()]'
        Expected = @()
    }
    @{
        Name     = 'A function that writes verbose output without the copy is named'
        Text     = & $supportsText @($pinLine, 'Write-Verbose ''x''') '[CmdletBinding()]'
        Expected = @($verboseMissing)
    }
    @{
        Name     = 'A function that runs a tool through a helper needs the copy'
        Text     = & $supportsText `
            @($pinLine, 'Invoke-GitHubCommand -Activity ''x'' -Argument @(''a'')') `
            '[CmdletBinding()]'
        Expected = @($verboseMissing)
    }
    @{
        Name     = 'A function that neither writes verbose output nor runs a tool needs none'
        Text     = & $supportsText @($pinLine, 'Invoke-Work') '[CmdletBinding()]'
        Expected = @()
    }
    @{
        Name     = 'A changing function that runs a tool needs all three'
        Text     = & $supportsText @($pinLine, 'Invoke-GitCommand -Activity ''x'' -Arguments @(''a'')')
        Expected = @($whatIfMissing, $confirmMissing, $verboseMissing)
    }
    @{
        Name     = 'A function that only names Write-Verbose in a comment needs none'
        Text     = & $supportsText @($pinLine, '# as Write-Verbose would', 'Invoke-Work') '[CmdletBinding()]'
        Expected = @()
    }
)

# Act / Assert
foreach ($case in $verboseCases) {
    $function = Get-SampleFunction -Text $case.Text
    Assert-Equal -Expected $case.Expected -Actual @(Get-PreferenceCopyProblem -Function $function) `
        -Message "Get-PreferenceCopyProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module whose public function reaches gh through two private helpers of its own
$basePattern = '\b(Write-Verbose|Invoke-GitCommand|Invoke-GitHubCommand|Invoke-GitHubApi|' +
    'Invoke-NativeCommand|Invoke-NativeRead)\b'
$modulePattern = $basePattern.Replace(')\b', '|Invoke-SampleApi|Invoke-SampleChange)\b')
$helpers = @{
    'Invoke-SampleApi'    = Get-SampleFunction `
        -Text 'function Invoke-SampleApi { Invoke-GitHubCommand -Argument @(''a'') }'
    'Invoke-SampleChange' = Get-SampleFunction -Text 'function Invoke-SampleChange { Invoke-SampleApi }'
    'Get-SampleName'      = Get-SampleFunction `
        -Text "function Get-SampleName {`n    <# .LINK`n    Invoke-SampleApi #>`n    'name'`n}"
}
$caller = Get-SampleFunction -Text (& $supportsText @($pinLine, 'Invoke-SampleChange') '[CmdletBinding()]')

# Act
$pattern = Get-VerboseSourcePattern -Functions $helpers

# Assert
Assert-Equal -Expected $basePattern -Actual (Get-VerboseSourcePattern) `
    -Message 'Get-VerboseSourcePattern: with no functions, Write-Verbose and the plumbing helpers alone'
Assert-Equal -Expected $modulePattern -Actual $pattern `
    -Message ('Get-VerboseSourcePattern: a helper that runs a tool is added,' +
        ' then the one that calls it, and not one that only names it in help')
Assert-Equal -Expected @() -Actual @(Get-PreferenceCopyProblem -Function $caller) `
    -Message 'Get-PreferenceCopyProblem: against the plumbing pattern a call to the module''s own helper needs no copy'
Assert-Equal -Expected @($verboseMissing) `
    -Actual @(Get-PreferenceCopyProblem -Function $caller -VerbosePattern $pattern) `
    -Message 'Get-PreferenceCopyProblem: against the module''s pattern the same call needs the copy'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - help with and without a description of its own
$noDescription = 'Test-Sample has no .DESCRIPTION of its own: ' +
    'Get-Help -Full and the Gallery page show only the synopsis'
$descriptionCases = @(
    @{
        Name     = 'A description passes'
        Help     = '.DESCRIPTION~    Reads the thing and returns it.'
        Expected = @()
    }
    @{
        Name     = 'A description with the -WhatIf sentence and more passes'
        Help     = '.DESCRIPTION~    Removes the thing. With -WhatIf nothing is changed and nothing is returned.'
        Expected = @()
    }
    @{
        Name     = 'No description is named'
        Help     = '.PARAMETER Name~    The name.'
        Expected = @($noDescription)
    }
    @{
        Name     = 'Only the -WhatIf sentence is no description'
        Help     = '.DESCRIPTION~    With -WhatIf nothing is changed and nothing is returned.'
        Expected = @($noDescription)
    }
    @{
        Name     = 'An empty description is named'
        Help     = '.DESCRIPTION~.PARAMETER Name~    The name.'
        Expected = @($noDescription)
    }
)

# Act / Assert
foreach ($case in $descriptionCases) {
    $function = Get-HelpSampleFunction -Help $case.Help
    Assert-Equal -Expected $case.Expected -Actual @(Get-HelpDescriptionProblem -Function $function) `
        -Message "Get-HelpDescriptionProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with one command that pins the preference and one that does not, each running a cmdlet
# that fails without throwing
$scratch = Join-Path ([IO.Path]::GetTempPath()) "preference-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $moduleText = @(
        'Set-StrictMode -Version Latest'
        '$ErrorActionPreference = ''Stop'''
        'function Remove-Unpinned {'
        '    [CmdletBinding()]'
        '    param([string]$Path)'
        '    try {'
        '        Remove-Item -LiteralPath $Path'
        '        ''went on'''
        '    }'
        '    catch {'
        "        $raise"
        '    }'
        '}'
        'function Remove-Pinned {'
        '    [CmdletBinding()]'
        '    param([string]$Path)'
        '    try {'
        '        $ErrorActionPreference = ''Stop'''
        '        Remove-Item -LiteralPath $Path'
        '        ''went on'''
        '    }'
        '    catch {'
        "        $raise"
        '    }'
        '}'
        'function ConvertTo-CommandError { param($ErrorRecord, $Command) $ErrorRecord }'
        'Export-ModuleMember -Function Remove-Unpinned, Remove-Pinned'
    )
    $modulePath = Join-Path $scratch 'Preference.psm1'
    Set-Content -LiteralPath $modulePath -Value $moduleText
    Import-Module $modulePath -Force
    $missing = Join-Path $scratch 'missing.txt'

    # Act
    $unpinned = Remove-Unpinned -Path $missing -ErrorAction SilentlyContinue 2>$null
    $pinnedId = try {
        Remove-Pinned -Path $missing -ErrorAction SilentlyContinue 2>$null
    }
    catch {
        $_.FullyQualifiedErrorId
    }

    $tree = (Get-SampleScript -Text (Get-Content -LiteralPath $modulePath -Raw))
    $isFunction = { param($node) $node -is [FunctionDefinitionAst] }
    $functions = @($tree.FindAll($isFunction, $true) | Where-Object { $_.Name -like 'Remove-*' })
    $problems = @($functions | ForEach-Object { @(Get-ErrorPreferenceProblem -Function $_).Count })
}
finally {
    Remove-Module Preference -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

# Assert
Assert-Equal -Expected 'went on' -Actual $unpinned `
    -Message 'Without the pin, -ErrorAction SilentlyContinue hides a cmdlet that failed, and the function goes on'
Assert-Equal -Expected 'PathNotFound,Remove-Pinned' -Actual $pinnedId `
    -Message 'With the pin, the same failure is raised, whatever the caller passed'
Assert-Equal -Expected @(1, 0) -Actual $problems `
    -Message 'and the detector reports the function that goes on, and not the one that stops'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$helpCases = @(
    @{
        Name       = 'Help that says what it takes and returns, with the matching [OutputType()], has no problem'
        Help       = '.INPUTS~None~.OUTPUTS~System.String~The name.'
        Attributes = '[OutputType([string])]'
        Expected   = @()
    }
    @{
        Name       = 'and so does .OUTPUTS None without a declared type, however it is spelled'
        Help       = '.INPUTS~System.String~.OUTPUTS~none. Nothing is returned.'
        Attributes = ''
        Expected   = @()
    }
    @{
        Name       = 'and so does .OUTPUTS None with [OutputType([void])]'
        Help       = '.INPUTS~None~.OUTPUTS~None'
        Attributes = '[OutputType([void])]'
        Expected   = @()
    }
    @{
        Name       = 'and so does a type given by name, or in a second attribute'
        Help       = '.INPUTS~None~.OUTPUTS~Some.Type~The thing.'
        Attributes = '[OutputType(''Some.Type'')] [OutputType([int])]'
        Expected   = @()
    }
    @{
        Name       = 'Help with neither keyword lacks both'
        Help       = ''
        Attributes = ''
        Expected   = @('Test-Sample has no .INPUTS', 'Test-Sample has no .OUTPUTS')
    }
    @{
        Name       = 'Help with only .INPUTS lacks .OUTPUTS'
        Help       = '.INPUTS~None'
        Attributes = ''
        Expected   = @('Test-Sample has no .OUTPUTS')
    }
    @{
        Name       = 'Help with only .OUTPUTS lacks .INPUTS'
        Help       = '.OUTPUTS~None'
        Attributes = ''
        Expected   = @('Test-Sample has no .INPUTS')
    }
    @{
        Name       = 'A keyword with no text is as good as missing'
        Help       = '.INPUTS~~.OUTPUTS~None'
        Attributes = ''
        Expected   = @('Test-Sample has no .INPUTS')
    }
    @{
        Name       = 'Output that is not None needs an [OutputType()]'
        Help       = '.INPUTS~None~.OUTPUTS~System.String~The name.'
        Attributes = ''
        Expected   = @('Test-Sample has .OUTPUTS but declares no [OutputType()] of a real type')
    }
    @{
        Name       = 'and [OutputType([void])] is not one'
        Help       = '.INPUTS~None~.OUTPUTS~System.String~The name.'
        Attributes = '[OutputType([System.Void])]'
        Expected   = @('Test-Sample has .OUTPUTS but declares no [OutputType()] of a real type')
    }
    @{
        Name       = 'and a word that only starts with None is not None'
        Help       = '.INPUTS~None~.OUTPUTS~Nonexistent things.'
        Attributes = ''
        Expected   = @('Test-Sample has .OUTPUTS but declares no [OutputType()] of a real type')
    }
    @{
        Name       = 'Output that is None must not declare a real type'
        Help       = '.INPUTS~None~.OUTPUTS~None'
        Attributes = '[OutputType([string], [int])]'
        Expected   = @('Test-Sample has .OUTPUTS None but declares [OutputType([string], [int])]')
    }
    @{
        Name       = 'Help with no .OUTPUTS is reported once, whatever is declared'
        Help       = '.INPUTS~None'
        Attributes = '[OutputType([string])]'
        Expected   = @('Test-Sample has no .OUTPUTS')
    }
)

# Act / Assert
foreach ($case in $helpCases) {
    $function = Get-HelpSampleFunction -Help $case.Help -Attributes $case.Attributes
    Assert-Equal -Expected $case.Expected -Actual @(Get-HelpIoProblem -Function $function) `
        -Message "Get-HelpIoProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$bareFunction = Get-SampleFunction -Text 'function Test-Sample { param() process { Invoke-Work } }'

# Act
$noHelpProblems = @(Get-HelpIoProblem -Function $bareFunction)

# Assert
Assert-Equal -Expected @('Test-Sample has no .INPUTS', 'Test-Sample has no .OUTPUTS') -Actual $noHelpProblems `
    -Message 'Get-HelpIoProblem: A function with no help block at all lacks both keywords'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$names = 'Name', 'Count', 'Verbose', 'vb'
$exampleCases = @(
    @{
        Name     = 'An example that calls the function with its own parameters has no problem'
        Help     = '.EXAMPLE~Test-Sample -Name ''a''~Test-Sample -Name ''b'' -Verbose~Runs it twice.'
        Expected = @()
    }
    @{
        Name     = 'and so does one using an alias, or the wrong case'
        Help     = '.EXAMPLE~Test-Sample -Count 3~Test-Sample -name ''a'' -vb'
        Expected = @()
    }
    @{
        Name     = 'and so does one using the colon form, a splat, or a module-qualified name'
        Help     = '.EXAMPLE~Test-Sample -Name:''a''~Test-Sample @params~TaffarelJr.Sample\Test-Sample -Name 1'
        Expected = @()
    }
    @{
        Name     = 'and so does a call inside a pipeline or a script block'
        Help     = '.EXAMPLE~1..3 | ForEach-Object { Test-Sample -Name $_ } | Out-Null'
        Expected = @()
    }
    @{
        Name     = 'and the parameters of another command are not checked'
        Help     = '.EXAMPLE~Get-ChildItem -Bogus | Test-Sample -Name 1'
        Expected = @()
    }
    @{
        Name     = 'and so is a call through a variable, whose command is not known'
        Help     = '.EXAMPLE~& $command -Bogus 1'
        Expected = @()
    }
    @{
        Name     = 'and the text after the first blank line is prose, not code'
        Help     = '.EXAMPLE~Test-Sample -Name ''a''~~Counts (the files, and -Bogus is not checked in prose.'
        Expected = @()
    }
    @{
        Name     = 'and a second example is read as well'
        Help     = '.EXAMPLE~Test-Sample -Name 1~.EXAMPLE~Test-Sample -Count 2'
        Expected = @()
    }
    @{
        Name     = 'Help with no example has none to read'
        Help     = '.DESCRIPTION~Does a thing.'
        Expected = @('Test-Sample has no .EXAMPLE')
    }
    @{
        Name     = 'An example with no text has no code'
        Help     = '.EXAMPLE~~.EXAMPLE~Test-Sample -Name 1'
        Expected = @('Test-Sample .EXAMPLE 1 has no code')
    }
    @{
        Name     = 'An example that calls the function with a parameter it lacks is reported, by number'
        Help     = '.EXAMPLE~Test-Sample -Name 1~.EXAMPLE~Test-Sample -Name 1 -Bogus 2'
        Expected = @('Test-Sample .EXAMPLE 2 uses -Bogus, which is not a parameter of Test-Sample')
    }
    @{
        Name     = 'and so is an abbreviated parameter name'
        Help     = '.EXAMPLE~Test-Sample -Nam 1'
        Expected = @('Test-Sample .EXAMPLE 1 uses -Nam, which is not a parameter of Test-Sample')
    }
    @{
        Name     = 'Each such parameter is reported, in the order of the calls'
        Help     = '.EXAMPLE~Test-Sample -Zed 1~Test-Sample -Name 1 -Alpha 2'
        Expected = @(
            'Test-Sample .EXAMPLE 1 uses -Zed, which is not a parameter of Test-Sample'
            'Test-Sample .EXAMPLE 1 uses -Alpha, which is not a parameter of Test-Sample'
        )
    }
)

# Act / Assert
foreach ($case in $exampleCases) {
    $function = Get-HelpSampleFunction -Help $case.Help
    Assert-Equal -Expected $case.Expected -Actual @(Get-ExampleProblem -Function $function -ParameterName $names) `
        -Message "Get-ExampleProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$unparseable = Get-HelpSampleFunction -Help '.EXAMPLE~Test-Sample -Name 1~.EXAMPLE~Test-Sample -Name ''unclosed'

# Act
$unparseableProblems = @(Get-ExampleProblem -Function $unparseable -ParameterName $names)

# Assert
$unparseableOk = $unparseableProblems.Count -eq 1 -and
$unparseableProblems[0] -like 'Test-Sample .EXAMPLE 2 does not parse: *'
Assert-That -Condition $unparseableOk `
    -Message 'Get-ExampleProblem: An example that does not parse is reported, by number, with the parser''s words'

#───────────────────────────────────────────────────────────────────────────────
# Act
$noHelpExampleProblems = @(Get-ExampleProblem -Function $bareFunction -ParameterName $names)
$noNamesProblems = @(Get-ExampleProblem -Function $bareFunction -ParameterName @())

# Assert
Assert-Equal -Expected @('Test-Sample has no .EXAMPLE') -Actual $noHelpExampleProblems `
    -Message 'Get-ExampleProblem: A function with no help block has no example'
Assert-Equal -Expected @('Test-Sample has no .EXAMPLE') -Actual $noNamesProblems `
    -Message 'Get-ExampleProblem: A function with no parameters at all is still read'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$linkCases = @(
    @{
        Name     = 'A function whose only .LINK is the README has no problem'
        Help     = ".LINK~$readmeUri"
        Expected = @()
    }
    @{
        Name     = 'and so has one that names related commands after it'
        Help     = ".LINK~$readmeUri~.LINK~Get-Other~.LINK~https://example.com/"
        Expected = @()
    }
    @{
        Name     = 'Help with no .LINK has none'
        Help     = '.DESCRIPTION~Does a thing.'
        Expected = @('Test-Sample has no .LINK')
    }
    @{
        Name     = 'A first .LINK that is something else is reported, even when a later one is the README'
        Help     = ".LINK~Get-Other~.LINK~$readmeUri"
        Expected = @("Test-Sample first .LINK is 'Get-Other', not $readmeUri")
    }
    @{
        Name     = 'and so is one that differs only by case'
        Help     = ".LINK~$($readmeUri.ToLowerInvariant())"
        Expected = @("Test-Sample first .LINK is '$($readmeUri.ToLowerInvariant())', not $readmeUri")
    }
    @{
        Name     = 'and so is the CHANGELOG'
        Help     = ".LINK~$changelogUri"
        Expected = @("Test-Sample first .LINK is '$changelogUri', not $readmeUri")
    }
)

# Act / Assert
foreach ($case in $linkCases) {
    $function = Get-HelpSampleFunction -Help $case.Help
    Assert-Equal -Expected $case.Expected -Actual @(Get-HelpLinkProblem -Function $function -ReadmeUri $readmeUri) `
        -Message "Get-HelpLinkProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$noHelpLinkProblems = @(Get-HelpLinkProblem -Function $bareFunction -ReadmeUri $readmeUri)

# Assert
Assert-Equal -Expected @('Test-Sample has no .LINK') -Actual $noHelpLinkProblems `
    -Message 'Get-HelpLinkProblem: A function with no help block has no .LINK'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$setCases = @(
    @{
        Name     = 'A command with no named parameter set has no problem'
        Command  = 'Test-SampleNoSet'
        Expected = @()
    }
    @{
        Name     = 'and so has one with a single set'
        Command  = 'Test-SampleOneSet'
        Expected = @()
    }
    @{
        Name     = 'and so has one with two sets and a default'
        Command  = 'Test-SampleSetPairDefault'
        Expected = @()
    }
    @{
        Name     = 'Two sets and no default are reported with their count'
        Command  = 'Test-SampleSetPair'
        Expected = @('Test-SampleSetPair has 2 parameter sets but no DefaultParameterSetName')
    }
    @{
        Name     = 'and so are three'
        Command  = 'Test-SampleSetTriple'
        Expected = @('Test-SampleSetTriple has 3 parameter sets but no DefaultParameterSetName')
    }
)

# Act / Assert
foreach ($case in $setCases) {
    $command = Get-Command -Name $case.Command
    Assert-Equal -Expected $case.Expected -Actual @(Get-DefaultParameterSetProblem -Command $command) `
        -Message "Get-DefaultParameterSetProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$pathCases = @(
    @{
        Name     = 'A Path that binds by property name and has the PSPath alias has no problem'
        Command  = 'Test-SamplePathAliased'
        Expected = @()
    }
    @{
        Name     = 'and so has a Path that binds only by value'
        Command  = 'Test-SamplePathByValue'
        Expected = @()
    }
    @{
        Name     = 'and so has a Path that is not piped at all'
        Command  = 'Test-SamplePathNotPiped'
        Expected = @()
    }
    @{
        Name     = 'and so has a parameter that is not named Path or LiteralPath'
        Command  = 'Test-SampleOtherName'
        Expected = @()
    }
    @{
        Name     = 'and so has a function with no such parameter'
        Command  = 'Test-SampleNoSet'
        Expected = @()
    }
    @{
        Name     = 'A Path that binds by property name without the alias is reported'
        Command  = 'Test-SamplePathPlain'
        Expected = @('Test-SamplePathPlain -Path binds by property name but has no PSPath alias')
    }
    @{
        Name     = 'and so is a LiteralPath'
        Command  = 'Test-SampleLiteralPathPlain'
        Expected = @('Test-SampleLiteralPathPlain -LiteralPath binds by property name but has no PSPath alias')
    }
    @{
        Name     = 'and so is an alias that is not PSPath'
        Command  = 'Test-SamplePathOtherAlias'
        Expected = @('Test-SamplePathOtherAlias -Path binds by property name but has no PSPath alias')
    }
    @{
        Name     = 'and so is a Path that binds by property name in only one of its sets'
        Command  = 'Test-SamplePathSetPair'
        Expected = @('Test-SamplePathSetPair -Path binds by property name but has no PSPath alias')
    }
    @{
        Name     = 'Both, when both lack it, Path first'
        Command  = 'Test-SampleBothPlain'
        Expected = @(
            'Test-SampleBothPlain -Path binds by property name but has no PSPath alias'
            'Test-SampleBothPlain -LiteralPath binds by property name but has no PSPath alias'
        )
    }
)

# Act / Assert
foreach ($case in $pathCases) {
    $command = Get-Command -Name $case.Command
    Assert-Equal -Expected $case.Expected -Actual @(Get-PSPathAliasProblem -Command $command) `
        -Message "Get-PSPathAliasProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$editionNotes = "PSData.ReleaseNotes is not $changelogUri"
$editionCases = @(
    @{
        Name     = 'A manifest for the Core edition, tagged for it, with the CHANGELOG as release notes, has no problem'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ Tags = @('Tally', 'PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @()
    }
    @{
        Name     = 'and so is one that also carries platform tags, which are neither required nor forbidden'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{
                PSData = @{ Tags = @('Windows', 'PSEdition_Core', 'Linux'); ReleaseNotes = $changelogUri }
            }
        }
        Expected = @()
    }
    @{
        Name     = 'and so is one that writes its single edition as a bare string'
        Manifest = @{
            CompatiblePSEditions = 'Core'
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @()
    }
    @{
        Name     = 'No CompatiblePSEditions is reported'
        Manifest = @{
            PrivateData = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('CompatiblePSEditions is not @(''Core'')')
    }
    @{
        Name     = 'and so are both editions'
        Manifest = @{
            CompatiblePSEditions = @('Desktop', 'Core')
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('CompatiblePSEditions is not @(''Core'')')
    }
    @{
        Name     = 'and so is Desktop alone'
        Manifest = @{
            CompatiblePSEditions = @('Desktop')
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('CompatiblePSEditions is not @(''Core'')')
    }
    @{
        Name     = 'and so is an empty list'
        Manifest = @{
            CompatiblePSEditions = @()
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('CompatiblePSEditions is not @(''Core'')')
    }
    @{
        Name     = 'and so is Core in the wrong case'
        Manifest = @{
            CompatiblePSEditions = @('core')
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('CompatiblePSEditions is not @(''Core'')')
    }
    @{
        Name     = 'Tags without PSEdition_Core are reported'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ Tags = @('Tally'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('PSData.Tags does not include PSEdition_Core')
    }
    @{
        Name     = 'and so is the tag in the wrong case'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ Tags = @('psedition_core'); ReleaseNotes = $changelogUri } }
        }
        Expected = @('PSData.Tags does not include PSEdition_Core')
    }
    @{
        Name     = 'and so is no Tags key'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ ReleaseNotes = $changelogUri } }
        }
        Expected = @('PSData.Tags does not include PSEdition_Core')
    }
    @{
        Name     = 'Release notes that are anything but the CHANGELOG address are reported'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = 'See CHANGELOG.md.' } }
        }
        Expected = @($editionNotes)
    }
    @{
        Name     = 'and so is the address in the wrong case'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{
                PSData = @{ Tags = @('PSEdition_Core'); ReleaseNotes = $changelogUri.ToUpperInvariant() }
            }
        }
        Expected = @($editionNotes)
    }
    @{
        Name     = 'and so is no ReleaseNotes key'
        Manifest = @{
            CompatiblePSEditions = @('Core')
            PrivateData          = @{ PSData = @{ Tags = @('PSEdition_Core') } }
        }
        Expected = @($editionNotes)
    }
    @{
        Name     = 'A manifest with no PrivateData lacks all three, in order'
        Manifest = @{ ModuleVersion = '0.1.0' }
        Expected = @(
            'CompatiblePSEditions is not @(''Core'')'
            'PSData.Tags does not include PSEdition_Core'
            $editionNotes
        )
    }
)

# Act / Assert
foreach ($case in $editionCases) {
    Assert-Equal -Expected $case.Expected `
        -Actual @(Get-ManifestEditionProblem -Manifest $case.Manifest -ReleaseNotesUri $changelogUri) `
        -Message "Get-ManifestEditionProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$readmeCases = @(
    @{
        Name     = 'A README with both headings has no problem'
        Text     = "# Sample`r`n`r`n## Errors`r`n`r`nText.`r`n`r`n## Name collisions`r`n`r`nText.`r`n"
        Expected = @()
    }
    @{
        Name     = 'and so has one with LF line endings, trailing blanks and the headings in any order'
        Text     = "## Name collisions  `n`nText.`n## Errors`t`nText."
        Expected = @()
    }
    @{
        Name     = 'A README with no Errors heading lacks it'
        Text     = "## Name collisions`r`n"
        Expected = @('README has no ''## Errors'' heading')
    }
    @{
        Name     = 'A README with no Name collisions heading lacks it'
        Text     = "## Errors`r`n"
        Expected = @('README has no ''## Name collisions'' heading')
    }
    @{
        Name     = 'An empty README lacks both, Errors first'
        Text     = ''
        Expected = @('README has no ''## Errors'' heading', 'README has no ''## Name collisions'' heading')
    }
    @{
        Name     = 'A heading at another level, in another case, or with more words, is not the heading'
        Text     = "### Errors`r`n## errors`r`n## Errors and exit codes`r`n## Name collisions (see below)`r`n"
        Expected = @('README has no ''## Errors'' heading', 'README has no ''## Name collisions'' heading')
    }
    @{
        Name     = 'and neither is the heading text in the middle of a line'
        Text     = "See ## Errors and ## Name collisions.`r`n"
        Expected = @('README has no ''## Errors'' heading', 'README has no ''## Name collisions'' heading')
    }
)

# Act / Assert
foreach ($case in $readmeCases) {
    Assert-Equal -Expected $case.Expected -Actual @(Get-ReadmeHeadingProblem -Text $case.Text) `
        -Message "Get-ReadmeHeadingProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$infoLoop = @'
foreach ($required in 'TaffarelJr.ProcessInvocation', 'TaffarelJr.GitHub.Core') {
    $loaded = Get-Module -Name $required
    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}
'@
$dotSource = @'
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}
'@
$twoNames = 'TaffarelJr.GitHub.Core', 'TaffarelJr.ProcessInvocation'
$noLoop = 'the root module has no foreach over a literal array of module names before its first dot-source'
$noInfo = 'the root module''s import loop does not call Import-Module -ModuleInfo'
$globalScope = 'the root module''s import loop imports into the global scope, not the module''s own'
$dependencyCases = @(
    @{
        Name     = 'A loop over exactly the required names, before the dot-sourcing, importing by -ModuleInfo, is fine'
        Script   = "Set-StrictMode -Version Latest`n$infoLoop`n$dotSource"
        Required = $twoNames
        Expected = @()
    }
    @{
        Name     = 'and so is a single name, in a loop over a bare string'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A')
        Expected = @()
    }
    @{
        Name     = 'and so are the names in @( ), and in any order'
        Script   = "foreach (`$r in @('B', 'A')) { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @()
    }
    @{
        Name     = 'and so is an import into -Scope Local'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r -Scope Local }`n$dotSource"
        Required = @('A')
        Expected = @()
    }
    @{
        Name     = 'and so is a module that dot-sources nothing'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r }"
        Required = @('A')
        Expected = @()
    }
    @{
        Name     = 'and so is the right loop after an unrelated literal one'
        Script   = "foreach (`$x in 'Q') { Write-Verbose `$x }`n$infoLoop`n$dotSource"
        Required = $twoNames
        Expected = @()
    }
    @{
        Name     = 'A module with no requirements and no import loop is fine'
        Script   = $dotSource
        Required = @()
        Expected = @()
    }
    @{
        Name     = 'and so is one whose dot-sourcing sits in a loop over literal folder names'
        Script   = "foreach (`$folder in 'Private', 'Public') {`n$dotSource`n}"
        Required = @()
        Expected = @()
    }
    @{
        Name     = 'A requirement with no loop at all is reported'
        Script   = $dotSource
        Required = $twoNames
        Expected = @($noLoop)
    }
    @{
        Name     = 'and so is a loop that comes after the first dot-source'
        Script   = "$dotSource`n$infoLoop"
        Required = $twoNames
        Expected = @($noLoop)
    }
    @{
        Name     = 'and so is a loop whose list is computed, not literal'
        Script   = "foreach (`$r in Get-Names) { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = $twoNames
        Expected = @($noLoop)
    }
    @{
        Name     = 'and so is a list that holds a variable'
        Script   = "foreach (`$r in 'A', `$other) { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @($noLoop)
    }
    @{
        Name     = 'and so is a list of numbers'
        Script   = "foreach (`$r in 1, 2) { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @($noLoop)
    }
    @{
        Name     = 'A loop that misses a required name is reported with both sets'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @('the root module''s import loop covers A, but RequiredModules lists A, B')
    }
    @{
        Name     = 'and so is one that names another module'
        Script   = "foreach (`$r in 'A', 'C') { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @('the root module''s import loop covers A, C, but RequiredModules lists A, B')
    }
    @{
        Name     = 'and so is one that names an extra module'
        Script   = "foreach (`$r in 'A', 'B', 'C') { Import-Module -ModuleInfo `$r }`n$dotSource"
        Required = @('A', 'B')
        Expected = @('the root module''s import loop covers A, B, C, but RequiredModules lists A, B')
    }
    @{
        Name     = 'A loop that imports by name is reported'
        Script   = "foreach (`$r in 'A') { Import-Module -Name `$r }`n$dotSource"
        Required = @('A')
        Expected = @($noInfo)
    }
    @{
        Name     = 'and so is one that imports nothing'
        Script   = "foreach (`$r in 'A') { Get-Module -Name `$r }`n$dotSource"
        Required = @('A')
        Expected = @($noInfo)
    }
    @{
        Name     = 'A loop that imports with -Global is reported'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r -Global }`n$dotSource"
        Required = @('A')
        Expected = @($globalScope)
    }
    @{
        Name     = 'and so is -Scope Global'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r -Scope Global }`n$dotSource"
        Required = @('A')
        Expected = @($globalScope)
    }
    @{
        Name     = 'and so is -Scope:Global, in any case'
        Script   = "foreach (`$r in 'A') { Import-Module -ModuleInfo `$r -scope:global }`n$dotSource"
        Required = @('A')
        Expected = @($globalScope)
    }
    @{
        Name     = 'A loop that imports by name and with -Global is reported for both'
        Script   = "foreach (`$r in 'A') { Import-Module -Name `$r -Global }`n$dotSource"
        Required = @('A')
        Expected = @($noInfo, $globalScope)
    }
    @{
        Name     = 'A module with no requirements that imports in such a loop is reported'
        Script   = "$infoLoop`n$dotSource"
        Required = @()
        Expected = @('the root module imports modules in a loop, but the manifest has no RequiredModules')
    }
)

# Act / Assert
foreach ($case in $dependencyCases) {
    $parsedScript = Get-SampleScript -Text $case.Script
    Assert-Equal -Expected $case.Expected `
        -Actual @(Get-DependencyScopeProblem -Script $parsedScript -RequiredModule $case.Required) `
        -Message "Get-DependencyScopeProblem: $($case.Name)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$withHashtable = @{
    RequiredModules = @(
        @{ ModuleName = 'A'; ModuleVersion = '0.1.0' }
        'B'
    )
}

# Act
$mixedNames = @(Get-ManifestRequiredModuleName -Manifest $withHashtable)
$noNames = @(Get-ManifestRequiredModuleName -Manifest @{ ModuleVersion = '0.1.0' })
$nullNames = @(Get-ManifestRequiredModuleName -Manifest @{ RequiredModules = $null })
$emptyNames = @(Get-ManifestRequiredModuleName -Manifest @{ RequiredModules = @() })

# Assert
Assert-Equal -Expected @('A', 'B') -Actual $mixedNames `
    -Message 'Get-ManifestRequiredModuleName: Hashtable entries give their ModuleName and bare entries themselves'
Assert-Equal -Expected @() -Actual $noNames `
    -Message 'and a manifest with no RequiredModules gives none'
Assert-Equal -Expected @() -Actual $nullNames -Message 'and so does one whose RequiredModules is $null'
Assert-Equal -Expected @() -Actual $emptyNames -Message 'and so does an empty list'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$psData = @{ Tags = @('A') }

# Act
$found = Get-ManifestPsData -Manifest @{ PrivateData = @{ PSData = $psData } }
$noPsData = Get-ManifestPsData -Manifest @{ PrivateData = @{ Other = 1 } }
$noPrivateData = Get-ManifestPsData -Manifest @{ ModuleVersion = '0.1.0' }

# Assert
Assert-Equal -Expected $psData -Actual $found -Message 'Get-ManifestPsData: The PSData of the manifest is returned'
Assert-Equal -Expected @{} -Actual $noPsData -Message 'and PrivateData without PSData gives an empty hashtable'
Assert-Equal -Expected @{} -Actual $noPrivateData -Message 'and so does a manifest without PrivateData'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$scratch = Join-Path ([IO.Path]::GetTempPath()) "surface-$([Guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path $scratch
try {
    $alphaPath = New-SampleModule -Root $scratch -Name 'Alpha'
    $betaPath = New-SampleModule -Root $scratch -Name 'Beta' `
        -Extra "; RequiredModules = @(@{ ModuleName = 'Alpha'; ModuleVersion = '0.1.0' })"
    $gammaPath = New-SampleModule -Root $scratch -Name 'Gamma' -RootModule 'Missing.psm1'
    $deltaPath = New-SampleModule -Root $scratch -Name 'Delta' -Extra "; RequiredModules = @('No.Such.Sibling')"
    $brokenPath = New-SampleModule -Root $scratch -Name 'Broken'
    Set-Content -LiteralPath $brokenPath -Value '@{ RootModule = '
    $null = New-SampleModule -Root $scratch -Name 'Epsilon' -Extra "; RequiredModules = @('Beta', 'External.Elsewhere')"
    $modulePathBefore = $env:PSModulePath

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $alphaProblems = @(Get-ManifestValidityProblem -Path $alphaPath)
    $betaProblems = @(Get-ManifestValidityProblem -Path $betaPath)

    # Assert
    Assert-Equal -Expected @() -Actual $alphaProblems `
        -Message 'Get-ManifestValidityProblem: A manifest Test-ModuleManifest accepts has no problem'
    Assert-Equal -Expected @() -Actual $betaProblems `
        -Message 'and so has one whose required module sits in the folder beside it, though it was never imported'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $gammaProblems = @(Get-ManifestValidityProblem -Path $gammaPath)
    $deltaProblems = @(Get-ManifestValidityProblem -Path $deltaPath)
    $brokenProblems = @(Get-ManifestValidityProblem -Path $brokenPath)
    $absentProblems = @(Get-ManifestValidityProblem -Path (Join-Path $scratch 'Absent' 'Absent.psd1'))

    # Assert
    Assert-That -Condition ($gammaProblems.Count -eq 1 -and $gammaProblems[0] -like 'Test-ModuleManifest fails: *') `
        -Message 'Get-ManifestValidityProblem: A manifest whose root module is missing is reported'
    Assert-That -Condition ($deltaProblems.Count -eq 1 -and $deltaProblems[0] -like 'Test-ModuleManifest fails: *') `
        -Message 'and so is one whose required module is nowhere'
    Assert-That -Condition ($brokenProblems.Count -eq 1 -and $brokenProblems[0] -like 'Test-ModuleManifest fails: *') `
        -Message 'and so is one that is not a manifest at all'
    Assert-That -Condition ($absentProblems.Count -eq 1 -and $absentProblems[0] -like 'Test-ModuleManifest fails: *') `
        -Message 'and so is a path with no file'
    Assert-That -Condition ($brokenProblems[0] -notmatch '[\r\n]') `
        -Message 'A reported problem is one line, though the error spans several'
    Assert-Equal -Expected $modulePathBefore -Actual $env:PSModulePath `
        -Message 'PSModulePath is put back, after a pass and after a failure'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $order = @(Get-PublicSurfaceImportOrder -Module 'Epsilon' -SourceRoot $scratch)

    # Assert
    Assert-Equal -Expected @('Alpha', 'Beta', 'Epsilon') -Actual $order `
        -Message 'Get-PublicSurfaceImportOrder: Requirements come first, hashtable or bare; outside ones are left out'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $withConverter = Join-Path $scratch 'WithConverter'
    $null = New-Item -ItemType Directory -Path (Join-Path $withConverter 'Private')
    Set-Content -LiteralPath (Join-Path $withConverter 'Private' 'ConvertTo-CommandError.ps1') -Value '# nothing'
    $withoutFile = Join-Path $scratch 'WithoutFile'
    $null = New-Item -ItemType Directory -Path (Join-Path $withoutFile 'Private')

    # Act
    $presentProblems = @(Get-ErrorConverterProblem -ModuleRoot $withConverter)
    $missingProblems = @(Get-ErrorConverterProblem -ModuleRoot $withoutFile)
    $noFolderProblems = @(Get-ErrorConverterProblem -ModuleRoot (Join-Path $scratch 'Nowhere'))

    # Assert
    Assert-Equal -Expected @() -Actual $presentProblems `
        -Message 'Get-ErrorConverterProblem: A module with Private\ConvertTo-CommandError.ps1 has no problem'
    Assert-Equal -Expected @('Private\ConvertTo-CommandError.ps1 does not exist') -Actual $missingProblems `
        -Message 'and one with a Private folder but not that file is reported'
    Assert-Equal -Expected @('Private\ConvertTo-CommandError.ps1 does not exist') -Actual $noFolderProblems `
        -Message 'and so is one with no Private folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a canonical copy, a module with the same text in the other line ending, and one that differs
    $canonical = Join-Path $scratch 'Canonical.ps1'
    [IO.File]::WriteAllText($canonical, "function ConvertTo-CommandError {`n    'shared'`n}`n")
    $sameText = Join-Path $scratch 'SameText'
    $null = New-Item -ItemType Directory -Path (Join-Path $sameText 'Private')
    [IO.File]::WriteAllText(
        (Join-Path $sameText 'Private' 'ConvertTo-CommandError.ps1'),
        "function ConvertTo-CommandError {`r`n    'shared'`r`n}`r`n")
    $drifted = Join-Path $scratch 'Drifted'
    $null = New-Item -ItemType Directory -Path (Join-Path $drifted 'Private')
    [IO.File]::WriteAllText(
        (Join-Path $drifted 'Private' 'ConvertTo-CommandError.ps1'),
        "function ConvertTo-CommandError {`n    'changed'`n}`n")

    # Act
    $sameProblems = @(Get-ErrorConverterProblem -ModuleRoot $sameText -CanonicalPath $canonical)
    $driftProblems = @(Get-ErrorConverterProblem -ModuleRoot $drifted -CanonicalPath $canonical)
    $absentProblems = @(Get-ErrorConverterProblem -ModuleRoot $withoutFile -CanonicalPath $canonical)

    # Assert
    $differs = 'Private\ConvertTo-CommandError.ps1 differs from the shared copy in TaffarelJr.GitHub.Core'
    Assert-Equal -Expected @() -Actual $sameProblems `
        -Message 'Get-ErrorConverterProblem: A copy with the canonical text, in the other line ending, has no problem'
    Assert-Equal -Expected @($differs) -Actual $driftProblems `
        -Message 'and a copy whose text differs is reported'
    Assert-Equal -Expected @('Private\ConvertTo-CommandError.ps1 does not exist') -Actual $absentProblems `
        -Message 'and a missing copy is reported as missing, not as different'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force
}

exit (Complete-TestRun)
