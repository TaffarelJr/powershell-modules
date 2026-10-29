using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# Shared by every module's own PublicSurface.Tests.ps1 - the checks are the
# same for each module, so they sit at the test root rather than inside any
# one module's own test tree.
function Get-ManifestRequiredModuleName {
    <#
    .SYNOPSIS
        Returns the name of every module a manifest's RequiredModules lists.
    .DESCRIPTION
        Not exported - a test-only fixture. An entry is a bare name or a
        hashtable whose ModuleName is the name.
    .PARAMETER Manifest
        A manifest, as Import-PowerShellDataFile reads it.
    .OUTPUTS
        The module names, in the order the manifest lists them.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )

    if (-not $Manifest.ContainsKey('RequiredModules') -or $null -eq $Manifest.RequiredModules) {
        return
    }

    foreach ($requirement in @($Manifest.RequiredModules)) {
        if ($requirement -is [string]) {
            $requirement
        }
        else {
            $requirement.ModuleName
        }
    }
}

function Get-ManifestPsData {
    <#
    .SYNOPSIS
        Returns the PSData hashtable of a manifest, or an empty one.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Manifest
        A manifest, as Import-PowerShellDataFile reads it.
    .OUTPUTS
        The manifest's PrivateData.PSData.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest
    )

    $privateData = $Manifest['PrivateData']
    if ($privateData -is [hashtable] -and $privateData.ContainsKey('PSData')) {
        return $privateData['PSData']
    }

    return @{}
}

function Get-PublicSurfaceImportOrder {
    <#
    .SYNOPSIS
        Returns a module of this repo and every repo module it requires,
        directly or not, each after the modules it requires.
    .DESCRIPTION
        Not exported - a test-only fixture for Test-ModulePublicSurface.

        The requirements are read from each manifest's RequiredModules, by
        name, whether an entry is a bare name or a hashtable. A required
        module this repo does not hold is left to Import-Module to resolve
        from the manifest; one it does hold is listed, so it is imported
        from src by path rather than found under that name elsewhere. A
        module reached twice is listed twice; the caller keeps the first.
    .PARAMETER Module
        The module's full name, such as TaffarelJr.Tally.
    .PARAMETER SourceRoot
        The folder holding one folder per module.
    .PARAMETER Chain
        The modules already being followed, outermost first, so a module
        that requires itself, directly or not, throws instead of looping.
    .OUTPUTS
        The module names, its requirements before it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [string[]]$Chain = @()
    )

    if ($Module -in $Chain) {
        throw "Modules require each other in a circle: $(@($Chain) + $Module -join ' -> ')"
    }

    $manifestPath = Join-Path $SourceRoot $Module "$Module.psd1"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "No module '$Module' in this repo: no $manifestPath - pass a full name, such as TaffarelJr.Tally."
    }

    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    foreach ($name in @(Get-ManifestRequiredModuleName -Manifest $manifest)) {
        if (Test-Path -LiteralPath (Join-Path $SourceRoot $name) -PathType Container) {
            Get-PublicSurfaceImportOrder -Module $name -SourceRoot $SourceRoot -Chain (@($Chain) + $Module)
        }
    }

    $Module
}

function Test-CatchRaisesCommandError {
    <#
    .SYNOPSIS
        Tells whether a catch clause raises its error through
        ConvertTo-CommandError.
    .DESCRIPTION
        Not exported - a test-only fixture. True when the clause's body
        calls $PSCmdlet.ThrowTerminatingError with an argument that holds
        a call to ConvertTo-CommandError, however deeply.
    .PARAMETER CatchClause
        The catch clause of a try statement.
    .OUTPUTS
        System.Boolean.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [CatchClauseAst]$CatchClause
    )

    $isRaise = {
        param($node)
        $node -is [InvokeMemberExpressionAst] -and
        $node.Expression -is [VariableExpressionAst] -and
        $node.Expression.VariablePath.UserPath -eq 'PSCmdlet' -and
        $node.Member -is [StringConstantExpressionAst] -and
        $node.Member.Value -eq 'ThrowTerminatingError'
    }
    $isConversion = {
        param($node)
        $node -is [CommandAst] -and $node.GetCommandName() -eq 'ConvertTo-CommandError'
    }

    foreach ($raise in $CatchClause.Body.FindAll($isRaise, $true)) {
        foreach ($argument in $raise.Arguments) {
            if (@($argument.FindAll($isConversion, $true)).Count -gt 0) {
                return $true
            }
        }
    }

    return $false
}

function Get-ErrorBoundaryProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with the error boundary of a public function.
    .DESCRIPTION
        Not exported - a test-only fixture. Each of the function's begin,
        process and end blocks that exists - or, with no named block, its
        whole body after param - must be exactly one try statement with a
        catch that raises through ConvertTo-CommandError (see
        Test-CatchRaisesCommandError). A function with no statements to
        hold one is a violation too.
    .PARAMETER Function
        The function's definition.
    .OUTPUTS
        One line per violation, starting with the function's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function
    )

    $name = $Function.Name
    $body = $Function.Body
    $blocks = [ordered]@{}
    if ($null -ne $body.BeginBlock) {
        $blocks['begin block'] = $body.BeginBlock
    }

    if ($null -ne $body.ProcessBlock) {
        $blocks['process block'] = $body.ProcessBlock
    }

    if ($null -ne $body.EndBlock) {
        $label = 'end block'
        if ($body.EndBlock.Unnamed) {
            $label = 'body'
        }

        $blocks[$label] = $body.EndBlock
    }

    if ($blocks.Count -eq 0) {
        "$name has no begin, process or end block to hold the error boundary"
        return
    }

    foreach ($label in $blocks.Keys) {
        $statements = @($blocks[$label].Statements)
        if ($statements.Count -eq 0) {
            "$name $label is empty, so it has no error boundary"
            continue
        }

        if ($statements.Count -ne 1 -or $statements[0] -isnot [TryStatementAst]) {
            "$name $label is not exactly one try statement"
            continue
        }

        $raising = @($statements[0].CatchClauses | Where-Object { Test-CatchRaisesCommandError -CatchClause $_ })
        if ($raising.Count -eq 0) {
            "$name $label has no catch that calls ThrowTerminatingError with ConvertTo-CommandError"
        }
    }
}

function Get-ErrorPreferenceProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with how a public function pins its error
        preference.
    .DESCRIPTION
        Not exported - a test-only fixture. A caller's -ErrorAction
        SilentlyContinue or Ignore becomes $ErrorActionPreference inside
        the function, so a cmdlet that fails without throwing - Remove-Item
        on a missing file - goes unnoticed and the function reports a
        success that never happened. The first statement of the try in the
        function's first block (begin, else process, else end or the whole
        body) must be $ErrorActionPreference = 'Stop', which holds for its
        other blocks and for every helper it calls.
    .PARAMETER Function
        The function's definition.
    .OUTPUTS
        One line per violation, starting with the function's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function
    )

    $name = $Function.Name
    $body = $Function.Body
    $first = $null
    foreach ($candidate in $body.BeginBlock, $body.ProcessBlock, $body.EndBlock) {
        if ($null -ne $candidate) {
            $first = $candidate
            break
        }
    }

    if ($null -eq $first) {
        "$name has no block to pin the error preference in"
        return
    }

    $try = @($first.Statements)[0]
    if ($try -isnot [TryStatementAst]) {
        "$name does not start with a try statement to pin the error preference in"
        return
    }

    $pin = @($try.Body.Statements)[0]
    $pinned = $pin -is [AssignmentStatementAst] -and
    $pin.Operator -eq 'Equals' -and
    $pin.Left -is [VariableExpressionAst] -and
    $pin.Left.VariablePath.UserPath -eq 'ErrorActionPreference' -and
    $pin.Right.Extent.Text -match '^[''"]Stop[''"]$'
    if (-not $pinned) {
        $statement = '$ErrorActionPreference = ''Stop'''
        "$name does not begin its try with $statement, so -ErrorAction SilentlyContinue would hide a failure"
    }
}

function Get-FunctionCodeText {
    <#
    .SYNOPSIS
        Returns a function's body as code alone, every comment removed.
    .DESCRIPTION
        Not exported - a test-only fixture. A .LINK or a sentence of help
        that names a command is not a call to it, so a check for what a
        function calls reads the body's tokens without its comments.
    .PARAMETER Function
        The function's definition.
    .OUTPUTS
        The code tokens' text, joined by spaces.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function
    )

    $tokens = $null
    $null = [Parser]::ParseInput($Function.Body.Extent.Text, [ref]$tokens, [ref]$null)
    $code = foreach ($token in $tokens) {
        if ($token.Kind -ne [TokenKind]::Comment) {
            $token.Text
        }
    }

    return ($code -join ' ')
}

function Get-VerboseSourcePattern {
    <#
    .SYNOPSIS
        Returns the pattern matching a call that writes verbose output,
        including the module's own functions that make one.
    .DESCRIPTION
        Not exported - a test-only fixture. Write-Verbose and the Invoke-*
        plumbing helpers print the verbose line a caller's -Verbose asks
        for. A function that reaches one of them through a private helper
        of its own is as cut off from the caller's preference as one that
        calls it directly, so every function whose body matches the pattern
        is added to it, then the functions that call those, until no more
        are added.
    .PARAMETER Functions
        The module's functions by name, public and private.
    .OUTPUTS
        The regular expression.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [hashtable]$Functions = @{}
    )

    $names = @(
        'Write-Verbose', 'Invoke-GitCommand', 'Invoke-GitHubCommand', 'Invoke-GitHubApi',
        'Invoke-NativeCommand', 'Invoke-NativeRead'
    )
    do {
        $pattern = '\b(' + ($names -join '|') + ')\b'
        $added = @(
            foreach ($name in @($Functions.PSBase.Keys | Sort-Object)) {
                if ($name -notin $names -and (Get-FunctionCodeText -Function $Functions[$name]) -match $pattern) {
                    $name
                }
            }
        )
        $names += $added
    } while ($added.Count -gt 0)

    return $pattern
}

function Get-PreferenceCopyProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with how a public function takes a caller's
        -WhatIf, -Confirm and -Verbose.
    .DESCRIPTION
        Not exported - a test-only fixture. A caller's -WhatIf sets
        $WhatIfPreference in the caller's own scope, which a module function
        never sees, so a function called from a -WhatIf run would still act;
        a caller's -Verbose is lost the same way. In its first try, after the
        error-preference pin, a function that declares SupportsShouldProcess
        copies $WhatIfPreference and $ConfirmPreference from the caller with
        $PSCmdlet.GetVariableValue, and a function that writes verbose output
        or runs a tool through an Invoke-* helper copies $VerbosePreference,
        each guarded by $PSBoundParameters.ContainsKey so the function's own
        switch still wins.
    .PARAMETER Function
        The function's definition.
    .PARAMETER VerbosePattern
        The pattern naming the calls that write verbose output, from
        Get-VerboseSourcePattern; without it, the plumbing helpers alone.
    .OUTPUTS
        One line per missing copy, starting with the function's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function,

        [string]$VerbosePattern = (Get-VerboseSourcePattern)
    )

    $paramBlock = $Function.Body.ParamBlock
    $binding = if ($null -ne $paramBlock) {
        @($paramBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' })[0]
    }

    $supports = $null -ne $binding -and
    @($binding.NamedArguments | Where-Object { $_.ArgumentName -eq 'SupportsShouldProcess' }).Count -gt 0
    $verbose = (Get-FunctionCodeText -Function $Function) -match $VerbosePattern
    $wanted = @(
        if ($supports) { 'WhatIf'; 'Confirm' }
        if ($verbose) { 'Verbose' }
    )
    if ($wanted.Count -eq 0) {
        return
    }

    $body = $Function.Body
    $first = $null
    foreach ($candidate in $body.BeginBlock, $body.ProcessBlock, $body.EndBlock) {
        if ($null -ne $candidate) {
            $first = $candidate
            break
        }
    }

    # A missing block or try is reported by the pin check; there is nothing to look inside here.
    $try = if ($null -ne $first) { @($first.Statements)[0] } else { $null }
    if ($try -isnot [TryStatementAst]) {
        return
    }

    $statements = @($try.Body.Statements)
    $effects = @{
        WhatIf  = 'a function invoked with -WhatIf that calls it would still change things'
        Confirm = 'a function invoked with -Confirm that calls it would not be asked'
        Verbose = 'a function invoked with -Verbose that calls it would print no verbose line'
    }
    foreach ($preference in $wanted) {
        $condition = "-not`$PSBoundParameters.ContainsKey('$preference')"
        $copy = "{`$${preference}Preference=`$PSCmdlet.GetVariableValue('${preference}Preference')}"
        $found = $false
        foreach ($statement in $statements) {
            if ($statement -isnot [IfStatementAst]) {
                continue
            }

            $clause = $statement.Clauses[0]
            if (($clause.Item1.Extent.Text -replace '\s', '') -eq $condition -and
                ($clause.Item2.Extent.Text -replace '\s', '') -eq $copy) {
                $found = $true
                break
            }
        }

        if (-not $found) {
            "$($Function.Name) does not copy a caller's ${preference}Preference after its pin: $($effects[$preference])"
        }
    }
}

function Get-HelpDescriptionProblem {
    <#
    .SYNOPSIS
        Returns a line when a public function's help has no description of
        its own.
    .DESCRIPTION
        Not exported - a test-only fixture. Get-Help -Full and the Gallery
        page show .DESCRIPTION under the synopsis. A missing one, or one that
        holds only the standard -WhatIf sentence, leaves a reader with the
        synopsis alone.
    .PARAMETER Function
        The function's definition.
    .OUTPUTS
        One line when the description is missing or says nothing, starting
        with the function's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function
    )

    $help = $Function.GetHelpContent()
    $description = if ($null -ne $help -and $null -ne $help.Description) { [string]$help.Description } else { '' }
    $own = ($description -replace 'With -WhatIf nothing is changed and nothing is returned\.', '').Trim()
    if ($own -eq '') {
        "$($Function.Name) has no .DESCRIPTION of its own: Get-Help -Full and the Gallery page show only the synopsis"
    }
}

function Get-ErrorConverterProblem {
    <#
    .SYNOPSIS
        Returns a line when a module has no ConvertTo-CommandError of its
        own.
    .DESCRIPTION
        Not exported - a test-only fixture. The converter is a private
        function of every module, because a private helper that raised the
        error itself would not stop its caller. Every module's copy is the
        same text, line endings aside, so a change is made once and carried
        to all of them.
    .PARAMETER ModuleRoot
        The module's folder.
    .PARAMETER CanonicalPath
        The copy every other is compared with. Leave it out to check only
        that the file exists.
    .OUTPUTS
        One line when Private\ConvertTo-CommandError.ps1 is missing, or
        differs from the canonical copy.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot,

        [string]$CanonicalPath
    )

    $path = Join-Path $ModuleRoot 'Private' 'ConvertTo-CommandError.ps1'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        'Private\ConvertTo-CommandError.ps1 does not exist'
        return
    }

    if ($CanonicalPath) {
        $own = (Get-Content -LiteralPath $path -Raw) -replace "`r`n", "`n"
        $shared = (Get-Content -LiteralPath $CanonicalPath -Raw) -replace "`r`n", "`n"
        if ($own -cne $shared) {
            'Private\ConvertTo-CommandError.ps1 differs from the shared copy in TaffarelJr.GitHub.Core'
        }
    }
}

function Get-HelpIoProblem {
    <#
    .SYNOPSIS
        Returns what is missing or inconsistent in the .INPUTS and .OUTPUTS
        of a function's help.
    .DESCRIPTION
        Not exported - a test-only fixture. Both keywords must have text.
        When the first word of .OUTPUTS is not None, the function must
        declare an [OutputType()] of a real type; when it is None, it must
        not. [OutputType([void])] is no type at all.
    .PARAMETER Function
        The function's definition.
    .OUTPUTS
        One line per problem, starting with the function's name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function
    )

    $name = $Function.Name
    $inputs = @()
    $outputs = @()
    $help = $Function.GetHelpContent()
    if ($null -ne $help) {
        $inputs = @($help.Inputs | Where-Object { $_.Trim() })
        $outputs = @($help.Outputs | Where-Object { $_.Trim() })
    }

    if ($inputs.Count -eq 0) {
        "$name has no .INPUTS"
    }

    if ($outputs.Count -eq 0) {
        "$name has no .OUTPUTS"
        return
    }

    $declared = @()
    if ($null -ne $Function.Body.ParamBlock) {
        $attributes = @($Function.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'OutputType' })
        $declared = @($attributes | ForEach-Object { $_.PositionalArguments.Extent.Text })
    }

    $real = @($declared | Where-Object { $_ -notin '[void]', '[System.Void]' })
    $saysNone = $outputs[0].Trim() -match '^None\b'
    if (-not $saysNone -and $real.Count -eq 0) {
        "$name has .OUTPUTS but declares no [OutputType()] of a real type"
    }

    if ($saysNone -and $real.Count -gt 0) {
        "$name has .OUTPUTS None but declares [OutputType($($real -join ', '))]"
    }
}

function Get-ExampleProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with the examples in a function's help.
    .DESCRIPTION
        Not exported - a test-only fixture. The function needs at least
        one .EXAMPLE. An example's code is its lines up to the first blank
        one. It must hold something and parse, and a call in it to the
        function itself may use only parameters the function has, by name
        or alias. A parameter of a call to any other command, or an element
        of a splat, is not checked.
    .PARAMETER Function
        The function's definition.
    .PARAMETER ParameterName
        Every name and alias of the function's parameters.
    .OUTPUTS
        One line per problem, starting with the function's name and the
        example's number.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ParameterName
    )

    $name = $Function.Name
    $examples = @()
    $help = $Function.GetHelpContent()
    if ($null -ne $help) {
        $examples = @($help.Examples)
    }

    if ($examples.Count -eq 0) {
        "$name has no .EXAMPLE"
        return
    }

    $isCommand = { param($node) $node -is [CommandAst] }
    for ($number = 1; $number -le $examples.Count; $number++) {
        $code = (($examples[$number - 1]).Trim() -split '\r?\n[ \t]*\r?\n', 2)[0]
        if (-not $code) {
            "$name .EXAMPLE $number has no code"
            continue
        }

        $tokens = $null
        $parseErrors = $null
        $tree = [Parser]::ParseInput($code, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) {
            "$name .EXAMPLE $number does not parse: $($parseErrors[0].Message)"
            continue
        }

        foreach ($command in $tree.FindAll($isCommand, $true)) {
            $called = $command.GetCommandName()
            if ($null -eq $called -or ($called -split '\\')[-1] -ne $name) {
                continue
            }

            foreach ($element in $command.CommandElements) {
                if ($element -is [CommandParameterAst] -and $element.ParameterName -notin $ParameterName) {
                    "$name .EXAMPLE $number uses -$($element.ParameterName), which is not a parameter of $name"
                }
            }
        }
    }
}

function Get-HelpLinkProblem {
    <#
    .SYNOPSIS
        Returns a line when a function's first .LINK is not the expected one.
    .DESCRIPTION
        Not exported - a test-only fixture. Get-Help -Online opens the first
        link, so it has to be the module's README, exactly.
    .PARAMETER Function
        The function's definition.
    .PARAMETER ReadmeUri
        The address the first .LINK must be.
    .OUTPUTS
        One line when there is no .LINK or the first one differs.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionDefinitionAst]$Function,

        [Parameter(Mandatory)]
        [string]$ReadmeUri
    )

    $name = $Function.Name
    $links = @()
    $help = $Function.GetHelpContent()
    if ($null -ne $help) {
        $links = @($help.Links)
    }

    if ($links.Count -eq 0) {
        "$name has no .LINK"
    }
    elseif ($links[0] -cne $ReadmeUri) {
        "$name first .LINK is '$($links[0])', not $ReadmeUri"
    }
}

function Get-DefaultParameterSetProblem {
    <#
    .SYNOPSIS
        Returns a line when a command with several parameter sets names no
        default one.
    .DESCRIPTION
        Not exported - a test-only fixture. Without a default, PowerShell
        cannot tell which set a call that fits more than one belongs to.
    .PARAMETER Command
        The command, as Get-Command returns it.
    .OUTPUTS
        One line when there is more than one set and no default.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionInfo]$Command
    )

    $count = @($Command.ParameterSets).Count
    if ($count -gt 1 -and -not $Command.DefaultParameterSet) {
        "$($Command.Name) has $count parameter sets but no DefaultParameterSetName"
    }
}

function Get-PSPathAliasProblem {
    <#
    .SYNOPSIS
        Returns a line for each Path or LiteralPath parameter that binds by
        property name without the alias PSPath.
    .DESCRIPTION
        Not exported - a test-only fixture. Get-Item and Get-ChildItem
        output carries the path in PSPath, so a parameter that binds by
        property name needs that alias to take their output.
    .PARAMETER Command
        The command, as Get-Command returns it.
    .OUTPUTS
        One line per such parameter.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [FunctionInfo]$Command
    )

    foreach ($name in 'Path', 'LiteralPath') {
        if (-not $Command.Parameters.ContainsKey($name)) {
            continue
        }

        $parameter = $Command.Parameters[$name]
        $byProperty = @($parameter.ParameterSets.Values | Where-Object { $_.ValueFromPipelineByPropertyName })
        if ($byProperty.Count -gt 0 -and 'PSPath' -notin $parameter.Aliases) {
            "$($Command.Name) -$name binds by property name but has no PSPath alias"
        }
    }
}

function Get-ManifestEditionProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with the edition and release notes a manifest
        declares.
    .DESCRIPTION
        Not exported - a test-only fixture. CompatiblePSEditions must be
        exactly @('Core'), the tags must include PSEdition_Core, and
        ReleaseNotes must be the CHANGELOG's address, exactly. Tags for
        the operating systems are neither required nor forbidden.
    .PARAMETER Manifest
        A manifest, as Import-PowerShellDataFile reads it.
    .PARAMETER ReleaseNotesUri
        The address ReleaseNotes must be.
    .OUTPUTS
        One line per problem.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Manifest,

        [Parameter(Mandatory)]
        [string]$ReleaseNotesUri
    )

    $editions = @()
    if ($null -ne $Manifest['CompatiblePSEditions']) {
        $editions = @($Manifest['CompatiblePSEditions'])
    }

    if ($editions.Count -ne 1 -or $editions[0] -cne 'Core') {
        "CompatiblePSEditions is not @('Core')"
    }

    $psData = Get-ManifestPsData -Manifest $Manifest
    $tags = @()
    if ($null -ne $psData['Tags']) {
        $tags = @($psData['Tags'])
    }

    if ($tags -cnotcontains 'PSEdition_Core') {
        'PSData.Tags does not include PSEdition_Core'
    }

    if ($psData['ReleaseNotes'] -cne $ReleaseNotesUri) {
        "PSData.ReleaseNotes is not $ReleaseNotesUri"
    }
}

function Get-ManifestValidityProblem {
    <#
    .SYNOPSIS
        Returns a line when Test-ModuleManifest rejects a manifest.
    .DESCRIPTION
        Not exported - a test-only fixture. The folder holding the module's
        folder is put on PSModulePath while the manifest is tested, so a
        required module that sits beside it is found by name, as it would be
        once installed; Test-ModuleManifest does not accept a module that
        was only imported by path. Warnings are allowed.
    .PARAMETER Path
        The full path of the module's .psd1.
    .OUTPUTS
        One line, the first line of the error, when the test fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $siblings = Split-Path -Parent (Split-Path -Parent $Path)
    $original = $env:PSModulePath
    try {
        $env:PSModulePath = $siblings + [IO.Path]::PathSeparator + $original
        $null = Test-ModuleManifest -Path $Path -WarningAction SilentlyContinue -ErrorAction Stop
    }
    catch {
        "Test-ModuleManifest fails: $(($_.Exception.Message -split '\r?\n')[0])"
    }
    finally {
        $env:PSModulePath = $original
    }
}

function Get-ReadmeHeadingProblem {
    <#
    .SYNOPSIS
        Returns a line for each section a module README lacks.
    .DESCRIPTION
        Not exported - a test-only fixture. A section is a heading line, at
        level two and spelled exactly, that says what the module does when
        a command fails and when another module has a command of the same
        name.
    .PARAMETER Text
        The README's whole text.
    .OUTPUTS
        One line per missing heading.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    foreach ($heading in 'Errors', 'Name collisions') {
        $pattern = '(?m)^## ' + [regex]::Escape($heading) + '[ \t]*\r?$'
        if ($Text -cnotmatch $pattern) {
            "README has no '## $heading' heading"
        }
    }
}

function Get-CommandParameterName {
    <#
    .SYNOPSIS
        Returns the name of every parameter a command line names.
    .DESCRIPTION
        Not exported - a test-only fixture for Get-DependencyScopeProblem.
    .PARAMETER Command
        The command, from a parsed script.
    .OUTPUTS
        The parameter names, without their dash.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [CommandAst]$Command
    )

    foreach ($element in $Command.CommandElements) {
        if ($element -is [CommandParameterAst]) {
            $element.ParameterName
        }
    }
}

function Test-GlobalModuleImport {
    <#
    .SYNOPSIS
        Tells whether an Import-Module call imports into the global scope.
    .DESCRIPTION
        Not exported - a test-only fixture for Get-DependencyScopeProblem.
        True for -Global and for -Scope Global, which are the same.
    .PARAMETER Command
        The Import-Module call, from a parsed script.
    .OUTPUTS
        System.Boolean.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [CommandAst]$Command
    )

    $elements = @($Command.CommandElements)
    for ($index = 0; $index -lt $elements.Count; $index++) {
        $element = $elements[$index]
        if ($element -isnot [CommandParameterAst]) {
            continue
        }

        if ($element.ParameterName -eq 'Global') {
            return $true
        }

        if ($element.ParameterName -ne 'Scope') {
            continue
        }

        $value = $element.Argument
        if ($null -eq $value -and $index + 1 -lt $elements.Count) {
            $value = $elements[$index + 1]
        }

        if ($value -is [StringConstantExpressionAst] -and $value.Value -eq 'Global') {
            return $true
        }
    }

    return $false
}

function Get-DependencyScopeProblem {
    <#
    .SYNOPSIS
        Returns what is wrong with how a root module imports the modules
        its manifest requires.
    .DESCRIPTION
        Not exported - a test-only fixture. A call into another module is
        resolved through the global scope unless the module imported that
        one itself, so a module with RequiredModules needs, before its
        first dot-source, a foreach over a literal array of exactly those
        names whose body calls Import-Module -ModuleInfo, never -Global.
        A module with none must not have such a loop.
    .PARAMETER Script
        The root module's parsed script.
    .PARAMETER RequiredModule
        The names the manifest's RequiredModules lists; empty for none.
    .OUTPUTS
        One line per problem.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst]$Script,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$RequiredModule
    )

    $isDotSource = { param($node) $node -is [CommandAst] -and $node.InvocationOperator -eq 'Dot' }
    $isLoop = { param($node) $node -is [ForEachStatementAst] }
    $isImport = { param($node) $node -is [CommandAst] -and $node.GetCommandName() -eq 'Import-Module' }

    $firstDotSource = [int]::MaxValue
    $dotSources = @($Script.FindAll($isDotSource, $true))
    if ($dotSources.Count -gt 0) {
        $firstDotSource = $dotSources[0].Extent.StartOffset
    }

    $loops = @(
        foreach ($loop in $Script.FindAll($isLoop, $true)) {
            $names = @()
            try {
                $names = @($loop.Condition.SafeGetValue())
            }
            catch {
                $names = @()
            }

            if ($names.Count -eq 0 -or @($names | Where-Object { $_ -isnot [string] }).Count -gt 0) {
                continue
            }

            $imports = @($loop.Body.FindAll($isImport, $true))
            [PSCustomObject]@{
                Loop       = $loop
                Names      = $names
                Imports    = $imports
                ModuleInfo = @($imports | Where-Object { 'ModuleInfo' -in @(Get-CommandParameterName -Command $_) })
            }
        }
    )

    if ($RequiredModule.Count -eq 0) {
        $stray = @($loops | Where-Object { $_.ModuleInfo.Count -gt 0 })
        if ($stray.Count -gt 0) {
            'the root module imports modules in a loop, but the manifest has no RequiredModules'
        }

        return
    }

    $before = @($loops | Where-Object { $_.Loop.Extent.EndOffset -le $firstDotSource })
    if ($before.Count -eq 0) {
        'the root module has no foreach over a literal array of module names before its first dot-source'
        return
    }

    $wanted = @($RequiredModule | Sort-Object -Unique) -join ', '
    $chosen = $null
    foreach ($candidate in $before) {
        if ((@($candidate.Names | Sort-Object -Unique) -join ', ') -eq $wanted) {
            $chosen = $candidate
            break
        }
    }

    if ($null -eq $chosen) {
        $listed = @($before[0].Names | Sort-Object -Unique) -join ', '
        "the root module's import loop covers $listed, but RequiredModules lists $wanted"
        return
    }

    if ($chosen.ModuleInfo.Count -eq 0) {
        "the root module's import loop does not call Import-Module -ModuleInfo"
    }

    if (@($chosen.Imports | Where-Object { Test-GlobalModuleImport -Command $_ }).Count -gt 0) {
        "the root module's import loop imports into the global scope, not the module's own"
    }
}

function Test-ModulePublicSurface {
    <#
    .SYNOPSIS
        Checks one module's public surface: its manifest, its exports, the
        help Get-Help shows for them, how they fail, and a mirrored test for
        every function.
    .DESCRIPTION
        Not exported - a test-only fixture, the body of every module's own
        PublicSurface.Tests.ps1, so a run of one module's tests includes
        these checks for that module.

        The module is imported by path from src, after every repo module it
        requires, each by path too. The checks that concern the repository
        rather than one module - the LICENSE every manifest names - are
        repeated for each module; they are cheap.

        Every check is one assertion through TaffarelJr.TestKit, and its
        message names the module; the caller ends with Complete-TestRun.
        Each source file is parsed once, and each export's command and
        help are fetched once, for all of them. The detectors behind the
        later checks are the functions above, tested by
        PublicSurfaceTestHelper.Tests.ps1.
    .PARAMETER Module
        The module's full name, such as TaffarelJr.Tally.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the module, imported by path with the repo modules it requires first
    $repoRoot = (Get-Item -LiteralPath $PSScriptRoot).Parent.FullName
    $srcRoot = Join-Path $repoRoot 'src'
    $moduleRoot = Join-Path $srcRoot $Module
    $order = @(Get-PublicSurfaceImportOrder -Module $Module -SourceRoot $srcRoot | Select-Object -Unique)
    foreach ($name in $order) {
        Import-Module (Join-Path $srcRoot $name "$name.psd1") -Global -Force
    }

    $manifestPath = Join-Path $moduleRoot "$Module.psd1"
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    $exported = @($manifest.FunctionsToExport)
    $sourceFiles = @(Get-ChildItem -LiteralPath $moduleRoot -Recurse -File -Filter *.ps1)

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $publicFolder = Join-Path $moduleRoot 'Public'
    $files = @(Get-ChildItem -LiteralPath $publicFolder -Filter *.ps1 -File | ForEach-Object BaseName)
    $unlisted = @($files | Where-Object { $_ -notin $exported })
    $missing = @($exported | Where-Object { $_ -notin $files })

    # Act
    $mismatches = @(
        foreach ($function in $unlisted) {
            "$Module : Public/$function.ps1 is not in FunctionsToExport"
        }
        foreach ($function in $missing) {
            "$Module : FunctionsToExport lists $function with no Public file"
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $mismatches `
        -Message "${Module}: Every exported function has its own file under Public, and every Public file is exported"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - each source file parsed once, and each export's definition, command and help fetched once
    $parsed = @{}
    $functionAst = @{}
    foreach ($file in $sourceFiles) {
        $tokens = $null
        $parseErrors = $null
        $tree = [Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        $parsed[$file.FullName] = [PSCustomObject]@{
            Tree   = $tree
            Tokens = $tokens
        }
        foreach ($statement in $tree.EndBlock.Statements) {
            if ($statement -is [FunctionDefinitionAst]) {
                $functionAst[$statement.Name] = $statement
            }
        }
    }

    $defined = @($exported | Where-Object { $functionAst.ContainsKey($_) })
    $commands = @{}
    $helps = @{}
    foreach ($function in $exported) {
        $commands[$function] = Get-Command -Name $function -Module $Module
        $helps[$function] = @(Get-Help -Name $function -Full)[0]
    }

    $readmePath = Join-Path $moduleRoot 'README.md'
    $readme = ''
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $readme = [string](Get-Content -LiteralPath $readmePath -Raw)
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $requiredKeys = 'Author', 'CompanyName', 'Description', 'RootModule', 'PowerShellVersion'
    $requiredPsData = 'ProjectUri', 'LicenseUri', 'Tags', 'ReleaseNotes'
    $licenseUri = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
    $licensePath = Join-Path $repoRoot 'LICENSE'
    $licenseLines = @()
    if (Test-Path -LiteralPath $licensePath -PathType Leaf) {
        $licenseLines = @(Get-Content -LiteralPath $licensePath)
    }

    $holderLine = $licenseLines | Where-Object { $_ -match '^Copyright \(c\) \d{4} \S' } | Select-Object -First 1
    $copyright = $null
    $holder = $null
    if ($holderLine) {
        $copyright = $holderLine -replace '^Copyright (\(c\) \d{4} .+)$', '$1.'
        $holder = $holderLine -replace '^Copyright \(c\) \d{4} ', ''
    }

    # Act
    $psData = Get-ManifestPsData -Manifest $manifest
    $manifestProblems = @(
        foreach ($key in $requiredKeys) {
            if (-not $manifest[$key]) {
                "$Module : $key is empty"
            }
        }
        foreach ($key in $requiredPsData) {
            if (-not $psData[$key]) {
                "$Module : PSData.$key is empty"
            }
        }
        if ($manifest.PowerShellVersion -ne '7.4') {
            "$Module : PowerShellVersion is $($manifest.PowerShellVersion), not 7.4"
        }
        if ($psData['LicenseUri'] -ne $licenseUri) {
            "$Module : LicenseUri is not the repository's LICENSE"
        }
        if ($manifest.Author -cne $holder -or $manifest.CompanyName -cne $holder) {
            "$Module : Author and CompanyName are not '$holder', the holder named in the LICENSE"
        }
        if ($manifest.Copyright -cne $copyright) {
            "$Module : Copyright is not '$copyright', the holder and year of the LICENSE"
        }
        if ($exported -contains '*') {
            "$Module : FunctionsToExport is a wildcard"
        }
    )

    # Assert
    $manifestMessage = 'The manifest carries its author, company, copyright, description, URIs, tags ' +
        'and a literal export list'
    Assert-Equal -Expected @() -Actual $manifestProblems -Message "${Module}: $manifestMessage"
    Assert-That -Condition (Test-Path -LiteralPath $licensePath -PathType Leaf) `
        -Message "${Module}: The LICENSE file that every LicenseUri points at exists at the repository root"

    #───────────────────────────────────────────────────────────────────────────
    # Act - an unknown parameter is silently dropped by a function that is not advanced
    $notAdvanced = @(
        foreach ($function in $exported) {
            $command = $commands[$function]
            if (-not $command.CmdletBinding) {
                "$Module : $function"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $notAdvanced `
        -Message "${Module}: Every exported function is an advanced function, so a misspelled parameter is an error"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the analyzer's -WhatIf rule knows only some verbs; these also change something outside the process
    $changingVerbs = 'New', 'Set', 'Remove', 'Start', 'Stop', 'Restart', 'Reset', 'Update', 'Add', 'Clear', 'Copy',
    'Move', 'Rename', 'Save', 'Restore', 'Resume', 'Push', 'Merge', 'Switch', 'Sync', 'Close', 'Lock', 'Unlock',
    'Enable', 'Disable', 'Install', 'Connect', 'Disconnect', 'Register', 'Submit', 'Open'

    # Act - a function with one of them supports -WhatIf, or its file says why it need not
    $unguarded = @(
        foreach ($function in $exported) {
            $verb = ($function -split '-')[0]
            if ($verb -notin $changingVerbs) {
                continue
            }

            $command = $commands[$function]
            if ($command.Parameters.ContainsKey('WhatIf')) {
                continue
            }

            $file = Join-Path $moduleRoot 'Public' "$function.ps1"
            $rule = 'PSUseShouldProcessForStateChangingFunctions'
            $says = Select-String -LiteralPath $file -SimpleMatch -Pattern $rule -Quiet
            if (-not $says) {
                "$Module : $function changes state but has no -WhatIf and no suppression saying why"
            }
        }
    )

    # Assert
    $unguardedMessage = 'Every exported function with a state-changing verb supports -WhatIf, ' +
        'or suppresses the rule with a reason'
    Assert-Equal -Expected @() -Actual $unguarded -Message "${Module}: $unguardedMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Get-Help leaves -WhatIf and -Confirm blank for a function, so each carries these sentences
    $shouldProcessHelp = @{
        WhatIf  = 'Shows what would happen if the command runs. The command is not run.'
        Confirm = 'Prompts for confirmation before the command runs.'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act - help that PowerShell could not read shows up as the generated syntax line
    $helpProblems = @(
        foreach ($function in $exported) {
            $help = $helps[$function]
            $synopsis = ''
            if ($null -ne $help) {
                $synopsis = "$($help.Synopsis)".Trim()
            }
            if (-not $synopsis -or $synopsis -like "$function*") {
                "$Module : $function has no readable synopsis"
                continue
            }

            $parameters = @()
            $helpParameters = $help.PSObject.Properties['parameters']
            if ($helpParameters -and $helpParameters.Value -and
                $helpParameters.Value.PSObject.Properties['parameter']) {
                $parameters = @($helpParameters.Value.parameter)
            }
            foreach ($parameter in $parameters) {
                if (-not $parameter) {
                    continue
                }

                $text = ''
                if ($parameter.PSObject.Properties['description']) {
                    $text = (@($parameter.description) | ForEach-Object { $_.Text }) -join ''
                }
                if (-not $text.Trim()) {
                    "$Module : $function -$($parameter.name) has no description"
                }
                elseif ($shouldProcessHelp.ContainsKey($parameter.name) -and
                    ($text -replace '\s+', ' ').Trim() -cne $shouldProcessHelp[$parameter.name]) {
                    "$Module : $function -$($parameter.name) is not the standard sentence"
                }
            }
        }
    )

    # Assert
    $helpMessage = 'Every exported function shows a synopsis, and every parameter shows a description, in Get-Help'
    Assert-Equal -Expected @() -Actual $helpProblems -Message "${Module}: $helpMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - Get-Help silently drops a .PARAMETER entry whose parameter does not exist
    $isFunction = { param($node) $node -is [FunctionDefinitionAst] }
    $staleHelp = @(
        foreach ($file in $sourceFiles) {
            $tree = $parsed[$file.FullName].Tree
            $functions = $tree.FindAll($isFunction, $true)
            foreach ($function in $functions) {
                $help = $function.GetHelpContent()
                if ($null -eq $help) {
                    continue
                }

                $documented = @($help.Parameters.Keys)
                $real = @()
                if ($function.Body.ParamBlock) {
                    $real = @($function.Body.ParamBlock.Parameters |
                            ForEach-Object { $_.Name.VariablePath.UserPath.ToUpperInvariant() })
                }
                $binding = $null
                if ($function.Body.ParamBlock) {
                    $attributes = @($function.Body.ParamBlock.Attributes)
                    $binding = $attributes |
                        Where-Object { $_.TypeName.Name -eq 'CmdletBinding' } |
                        Select-Object -First 1
                }
                $supports = $null
                if ($binding) {
                    $supports = $binding.NamedArguments | Where-Object { $_.ArgumentName -eq 'SupportsShouldProcess' }
                }

                if ($supports -and $supports.Argument.Extent.Text -ne '$false') {
                    $real += 'WHATIF', 'CONFIRM'
                }
                foreach ($name in $documented) {
                    if ($name -notin $real) {
                        "$($file.Name) : $($function.Name) documents -$name, which is not a parameter"
                    }
                }
            }
        }
    )

    # Assert
    $staleMessage = 'Every .PARAMETER entry names a real parameter, or -WhatIf/-Confirm on a ShouldProcess function'
    Assert-Equal -Expected @() -Actual $staleHelp -Message "${Module}: $staleMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a help line that starts with a dot-word is read as a keyword and drops the whole block
    $helpKeywords = 'SYNOPSIS', 'DESCRIPTION', 'PARAMETER', 'EXAMPLE', 'INPUTS', 'OUTPUTS', 'NOTES', 'LINK',
    'COMPONENT', 'ROLE', 'FUNCTIONALITY', 'FORWARDHELPTARGETNAME', 'FORWARDHELPCATEGORY',
    'REMOTEHELPRUNSPACE', 'EXTERNALHELP'
    $gluedKeyword = '\S\s{2,}\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK)\b'
    $dotWordProblems = @(
        foreach ($file in $sourceFiles) {
            $tokens = $parsed[$file.FullName].Tokens
            $relative = $file.FullName.Substring($srcRoot.Length + 1)
            $blocks = @($tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Text.StartsWith('<#') })
            foreach ($block in $blocks) {
                foreach ($line in ($block.Text -split "`r?`n")) {
                    if ($line.Trim() -match '^\.([A-Za-z]\w*)' -and $Matches[1] -notin $helpKeywords) {
                        "$relative : a help line starts with '.$($Matches[1])'"
                    }
                    elseif ($line -match $gluedKeyword) {
                        "$relative : a help keyword '.$($Matches[1])' is glued onto the end of a line"
                    }
                }
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $dotWordProblems `
        -Message "${Module}: No help line in any source file starts with a dot-word that is not a help keyword"

    #───────────────────────────────────────────────────────────────────────────
    # Act - every function file has a test file at the mirrored path
    $testRoot = Join-Path $repoRoot 'test'
    $missingTests = @(
        foreach ($file in $sourceFiles) {
            $relative = $file.FullName.Substring($srcRoot.Length + 1)
            $parts = $relative -split '[\\/]'
            if ($parts.Count -ne 3 -or $parts[1] -notin 'Public', 'Private') {
                continue
            }

            $testFolder = Join-Path $testRoot $parts[0] $parts[1]
            $mirrored = @()
            if (Test-Path -LiteralPath $testFolder) {
                $mirrored = @(Get-ChildItem -LiteralPath $testFolder -File |
                        Where-Object {
                            $_.Name -like "$($file.BaseName).Tests.ps1" -or
                            $_.Name -like "$($file.BaseName).*.Tests.ps1"
                        })
            }
            if ($mirrored.Count -eq 0) {
                "$relative has no test file at test\$($parts[0])\$($parts[1])\"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $missingTests `
        -Message "${Module}: Every Public and Private function file has a mirrored test file"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a README that points readers to examples in Get-Help has to be telling the truth
    $exampleProblems = @(
        if ($readme -match 'and examples') {
            $withExamples = @($exported | Where-Object {
                    $help = $helps[$_]
                    $helpExamples = $null
                    if ($null -ne $help) {
                        $helpExamples = $help.PSObject.Properties['examples']
                    }
                    $helpExamples -and $helpExamples.Value -and $helpExamples.Value.PSObject.Properties['example']
                })
            if ($withExamples.Count -eq 0) {
                "$Module : the README promises examples, but no function has one"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $exampleProblems `
        -Message "${Module}: A README that points to examples in Get-Help belongs to a module that has some"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - where this module's documents are on GitHub
    $sourceUri = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src'
    $readmeUri = "$sourceUri/$Module/README.md"
    $changelogUri = "$sourceUri/$Module/CHANGELOG.md"

    # Act - a plain throw is skipped under -ErrorAction SilentlyContinue, so each block catches and raises it
    $boundaryProblems = @(
        foreach ($function in $exported) {
            if (-not $functionAst.ContainsKey($function)) {
                "$Module : $function has no definition in any .ps1 file of the module"
            }
        }
        foreach ($function in $defined) {
            foreach ($problem in Get-ErrorBoundaryProblem -Function $functionAst[$function]) {
                "$Module : $problem"
            }
        }
        $sharedConverter = Join-Path $srcRoot 'TaffarelJr.GitHub.Core' 'Private' 'ConvertTo-CommandError.ps1'
        foreach ($problem in Get-ErrorConverterProblem -ModuleRoot $moduleRoot -CanonicalPath $sharedConverter) {
            "$Module : $problem"
        }
    )

    # Assert
    $boundaryMessage = 'Every block of every exported function is one try whose catch raises through ' +
        'ThrowTerminatingError and ConvertTo-CommandError, and the module has that private function, ' +
        'the same as every other module'
    Assert-Equal -Expected @() -Actual $boundaryProblems -Message "${Module}: $boundaryMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - -ErrorAction SilentlyContinue becomes the preference inside a function, so each pins Stop again
    $preferenceProblems = @(
        foreach ($function in $defined) {
            foreach ($problem in Get-ErrorPreferenceProblem -Function $functionAst[$function]) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    $preferenceMessage = 'Every exported function begins its first try with $ErrorActionPreference = ''Stop'', ' +
        'so a caller''s -ErrorAction cannot hide a cmdlet that failed inside it'
    Assert-Equal -Expected @() -Actual $preferenceProblems -Message "${Module}: $preferenceMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a caller's -WhatIf or -Verbose sets a variable in the caller's scope, which a module function never sees
    $verbosePattern = Get-VerboseSourcePattern -Functions $functionAst
    $copyProblems = @(
        foreach ($function in $defined) {
            foreach ($problem in Get-PreferenceCopyProblem -Function $functionAst[$function] `
                    -VerbosePattern $verbosePattern) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    $copyMessage = 'Every function that supports -WhatIf copies a caller''s WhatIfPreference and ConfirmPreference ' +
        'after its pin, and every function that writes verbose output or runs a tool, itself or through one of ' +
        'the module''s own helpers, copies VerbosePreference, so a function invoked with -WhatIf or -Verbose ' +
        'that calls it behaves as the caller asked'
    Assert-Equal -Expected @() -Actual $copyProblems -Message "${Module}: $copyMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - Get-Help -Full and the Gallery page show .DESCRIPTION under the synopsis
    $descriptionProblems = @(
        foreach ($function in $defined) {
            foreach ($problem in Get-HelpDescriptionProblem -Function $functionAst[$function]) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    $descriptionMessage = 'Every exported function has a .DESCRIPTION of its own, not only the synopsis ' +
        'and the -WhatIf sentence'
    Assert-Equal -Expected @() -Actual $descriptionProblems -Message "${Module}: $descriptionMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - Get-Help and the editor learn what a function takes and returns from its help and its [OutputType()]
    $inputOutputProblems = @(
        foreach ($function in $defined) {
            foreach ($problem in Get-HelpIoProblem -Function $functionAst[$function]) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    $inputOutputMessage = 'Every exported function documents .INPUTS and .OUTPUTS, and declares [OutputType()] ' +
        'exactly when .OUTPUTS is not None'
    Assert-Equal -Expected @() -Actual $inputOutputProblems -Message "${Module}: $inputOutputMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - an example that does not parse, or names a parameter the function lacks, misleads the reader
    $examplesProblems = @(
        foreach ($function in $defined) {
            $parameterNames = @($commands[$function].Parameters.Values | ForEach-Object { $_.Name; $_.Aliases })
            foreach ($problem in Get-ExampleProblem -Function $functionAst[$function] -ParameterName $parameterNames) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    $examplesMessage = 'Every exported function has an .EXAMPLE, every example parses, and every call to the ' +
        'function in one uses only its parameters'
    Assert-Equal -Expected @() -Actual $examplesProblems -Message "${Module}: $examplesMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - Get-Help -Online opens the first .LINK
    $linkProblems = @(
        foreach ($function in $defined) {
            foreach ($problem in Get-HelpLinkProblem -Function $functionAst[$function] -ReadmeUri $readmeUri) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $linkProblems `
        -Message "${Module}: The first .LINK of every exported function is the module's README on GitHub"

    #───────────────────────────────────────────────────────────────────────────
    # Act - without a default parameter set, a call that fits two of them is an error
    $parameterSetProblems = @(
        foreach ($function in $exported) {
            foreach ($problem in Get-DefaultParameterSetProblem -Command $commands[$function]) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $parameterSetProblems `
        -Message "${Module}: Every exported function with more than one parameter set declares a default"

    #───────────────────────────────────────────────────────────────────────────
    # Act - Get-Item and Get-ChildItem output reaches a parameter only through its PSPath alias
    $pathAliasProblems = @(
        foreach ($function in $exported) {
            foreach ($problem in Get-PSPathAliasProblem -Command $commands[$function]) {
                "$Module : $problem"
            }
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $pathAliasProblems `
        -Message "${Module}: A Path or LiteralPath parameter that binds by property name has the alias PSPath"

    #───────────────────────────────────────────────────────────────────────────
    # Act - the Gallery shows the edition tag and the release notes link, and publishing runs Test-ModuleManifest
    $editionProblems = @(
        foreach ($problem in Get-ManifestEditionProblem -Manifest $manifest -ReleaseNotesUri $changelogUri) {
            "$Module : $problem"
        }
        foreach ($problem in Get-ManifestValidityProblem -Path $manifestPath) {
            "$Module : $problem"
        }
    )

    # Assert
    $editionMessage = 'The manifest declares the Core edition and its PSEdition_Core tag, names the CHANGELOG ' +
        'as its ReleaseNotes, and passes Test-ModuleManifest'
    Assert-Equal -Expected @() -Actual $editionProblems -Message "${Module}: $editionMessage"

    #───────────────────────────────────────────────────────────────────────────
    # Act - a reader looks to the README for how a call fails and for a command another module shares
    $readmeProblems = @(
        foreach ($problem in Get-ReadmeHeadingProblem -Text $readme) {
            "$Module : $problem"
        }
    )

    # Assert
    Assert-Equal -Expected @() -Actual $readmeProblems `
        -Message "${Module}: The README has an Errors section and a Name collisions section"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the root module, parsed, and the modules the manifest requires
    $rootTokens = $null
    $rootErrors = $null
    $rootScript = [Parser]::ParseFile((Join-Path $moduleRoot "$Module.psm1"), [ref]$rootTokens, [ref]$rootErrors)
    $requiredNames = @(Get-ManifestRequiredModuleName -Manifest $manifest)

    # Act - a call into a module that is only in RequiredModules is resolved through the global scope
    $dependencyProblems = @(
        foreach ($problem in Get-DependencyScopeProblem -Script $rootScript -RequiredModule $requiredNames) {
            "$Module : $problem"
        }
    )

    # Assert
    $dependencyMessage = 'A module with RequiredModules imports each into its own scope before it dot-sources ' +
        'anything, and one without has no such import loop'
    Assert-Equal -Expected @() -Actual $dependencyProblems -Message "${Module}: $dependencyMessage"
}
