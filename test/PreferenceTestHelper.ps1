using namespace System.Management.Automation

# Shared by every module's Verbose and WhatIfPropagation tests. A caller's
# -WhatIf or $VerbosePreference lives in the caller's own scope, so each module
# proves it reads them from there with the same two callers and one reader.
function Invoke-WhatIfCaller {
    <#
    .SYNOPSIS
        Runs a call from inside a function that supports -WhatIf.
    .DESCRIPTION
        Not exported - a test-only fixture. Run with -WhatIf, it sets
        $WhatIfPreference in its own scope, which is all a caller's -WhatIf
        does: the call it makes must pick that up for itself.
    .PARAMETER Call
        The call to make.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'The function only carries the -WhatIf its caller gave; the call under test asks.')]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Call
    )

    & $Call
}

function Invoke-VerboseCaller {
    <#
    .SYNOPSIS
        Runs a call from inside a function whose own $VerbosePreference is
        Continue.
    .DESCRIPTION
        Not exported - a test-only fixture. Setting the variable in its own
        scope is all a caller's -Verbose or session preference does: the call
        it makes must pick that up for itself.
    .PARAMETER Call
        The call to make.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Call
    )

    $VerbosePreference = 'Continue'
    & $Call
}

function Get-VerboseLine {
    <#
    .SYNOPSIS
        Runs a script block and returns the text of each verbose line it wrote.
    .DESCRIPTION
        Not exported - a test-only fixture. The block must ask for verbose
        output itself: with -Verbose, a preference, or Invoke-VerboseCaller.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        The text of each verbose line, one at a time. Wrap the call in @() to
        collect it as an array.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $records = & $ScriptBlock 4>&1
    foreach ($record in @($records)) {
        if ($record -is [VerboseRecord]) {
            $record.Message
        }
    }
}
