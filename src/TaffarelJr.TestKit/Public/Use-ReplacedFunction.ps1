using namespace System.Management.Automation

function Use-ReplacedFunction {
    <#
    .SYNOPSIS
        Runs a script block while one of a module's functions is replaced by
        a body of the test's own, then puts the original back.
    .DESCRIPTION
        The seam a unit test needs to stub a private helper: the module's
        function is swapped for -Body inside the module's own scope, so every
        call the module makes to it reaches the stub, the block runs, and the
        original is restored in a finally, whether or not the block throws.
        The block runs in the caller's scope, so a variable it assigns is the
        caller's, and what it writes is passed on one item at a time.

        The body sees the arguments the module passed, as any function does;
        a test that wants them records them from inside the body, into a
        variable of its own.

        A name the module does not define is refused, so a typo cannot stub
        nothing and pass. What the block throws is raised by this command, as
        a terminating error that carries the block's own exception.
    .PARAMETER Module
        The module whose function is replaced: the object Get-Module returns,
        or its name when exactly one module of that name is loaded.
    .PARAMETER Name
        The function to replace, as the module defines it.
    .PARAMETER Body
        The script block that stands in for the function while -ScriptBlock
        runs. It is given the same arguments the module passes.
    .PARAMETER ScriptBlock
        The code to run while the function is replaced.
    .INPUTS
        None.
    .OUTPUTS
        System.Object. Whatever the script block writes, one item at a time.
    .EXAMPLE
        $calls = [Collections.Generic.List[object]]::new()
        $module = Get-Module TaffarelJr.Example
        Use-ReplacedFunction -Module $module -Name 'Invoke-ExampleTool' `
            -Body { $calls.Add($args); 'stubbed' } `
            -ScriptBlock { Remove-ExampleThing -Name 'old' }
        Assert-Equal -Expected 1 -Actual $calls.Count -Message 'The tool was called once'

        Stubs the module's private tool runner for one call and records what
        it was asked to run.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Assert-Throws
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$Module,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Body,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $ErrorActionPreference = 'Stop'

        $target = $Module
        if ($target -isnot [PSModuleInfo]) {
            $loaded = @(Get-Module -Name "$Module")
            if ($loaded.Count -ne 1) {
                throw "-Module '$Module' names $($loaded.Count) loaded modules; give the module object from Get-Module."
            }

            $target = $loaded[0]
        }

        # Get-Command inside the module sees its private functions; the function:
        # drive there does not. A name the module does not define resolves, from
        # inside, to the very same global command a lookup from outside returns;
        # a module function, even one already replaced, does not. The definition
        # text is kept rather than the script block: replacing the function
        # rewrites that block in place, so only text captured now can rebuild the
        # original, bound to the module again.
        $original = & $target {
            param($FunctionName)
            Get-Command -Name $FunctionName -CommandType Function -ErrorAction Ignore
        } $Name
        $outside = Get-Command -Name $Name -CommandType Function -ErrorAction Ignore
        if ($null -eq $original -or [object]::ReferenceEquals($original, $outside)) {
            throw "Module '$($target.Name)' defines no function '$Name'."
        }

        $definition = $original.Definition
        & $target {
            param($FunctionName, $Replacement)
            Set-Item -LiteralPath "function:script:$FunctionName" -Value $Replacement
        } $Name $Body
        try {
            # Dot-sourced: a call with & gets a scope of its own, and the block's
            # assignments would be lost when it ends.
            . $ScriptBlock
        }
        finally {
            $restored = $target.NewBoundScriptBlock([scriptblock]::Create($definition))
            & $target {
                param($FunctionName, $Original)
                Set-Item -LiteralPath "function:script:$FunctionName" -Value $Original
            } $Name $restored
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
