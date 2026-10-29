using namespace System.Collections.Generic
using namespace System.Management.Automation

function Assert-Throws {
    <#
    .SYNOPSIS
        Asserts a script block throws, and optionally what it throws.
    .DESCRIPTION
        With neither -MessageLike nor -ExceptionType, any error counts,
        including a typo in a command name. Say what is expected whenever
        it matters.

        Both checks look at the exception thrown and every inner exception
        under it, since what was really thrown often arrives wrapped - the
        exception of a .NET method inside a MethodInvocationException, for
        one.

        A case that fails is counted and printed, not thrown: the file's
        exit code, from Complete-TestRun, is how it reaches the run.
    .PARAMETER ScriptBlock
        The code expected to throw.
    .PARAMETER Message
        Names the case: what was checked, under what condition.
    .PARAMETER MessageLike
        Wildcard patterns the thrown message must match, as -like matches
        them: ignoring case, whatever the current culture is, with * ? and
        [ ] as wildcards. Give several to check that it contains each of
        several things; each must match the message of the exception or of
        one of its inner exceptions. For a literal bracket, escape the text
        with [WildcardPattern]::Escape.
    .PARAMETER ExceptionType
        The type the thrown exception, or one of its inner exceptions, must
        be or derive from.
    .INPUTS
        None.
    .OUTPUTS
        None. The case is counted and printed.
    .EXAMPLE
        $read = { Get-Item -LiteralPath $missing -ErrorAction Stop }
        Assert-Throws -ScriptBlock $read `
            -MessageLike '*Cannot find path*' `
            -Message 'A missing file is an error'

        Passes only if the block throws with a message containing the text.
    .EXAMPLE
        Assert-Throws -ScriptBlock { [IO.File]::ReadAllText($missing) } `
            -ExceptionType ([IO.FileNotFoundException]) `
            -Message 'A missing file is not found'

        Passes although PowerShell wraps the exception in a
        MethodInvocationException: the inner exception is the one that
        matches.
    .EXAMPLE
        $pattern = "*no such folder '$([WildcardPattern]::Escape('[x]'))'*"
        Assert-Throws -ScriptBlock { Get-Folder '[x]' } `
            -MessageLike $pattern `
            -Message 'A bracketed name is named'

        Matches a message holding literal brackets.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/README.md
    .LINK
        Assert-That
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns',
        '',
        Justification = 'Named after xUnit''s Assert.Throws, which every test reads as a sentence.')]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateNotNullOrEmpty()]
        [string[]]$MessageLike,

        [ValidateNotNull()]
        [type]$ExceptionType
    )

    try {
        $ErrorActionPreference = 'Stop'

        $caught = $null
        try {
            # Discarded, not just unused:
            # a block that returns a value instead of throwing
            # would otherwise leak that value into the caller's own output stream.
            $null = & $ScriptBlock
        }
        catch {
            $caught = $_
        }

        if ($null -eq $caught) {
            Assert-That -Condition $false -Message "$Message (did not throw)"
            return
        }

        $chain = [List[Exception]]::new()
        $link = $caught.Exception
        while ($null -ne $link) {
            $chain.Add($link)
            $link = $link.InnerException
        }

        $links = $chain.ToArray()
        $thrown = $links[0]
        if ($ExceptionType) {
            $ofType = @($links.Where({ $_ -is $ExceptionType }))
            if ($ofType.Count -eq 0) {
                $types = $links.ForEach({ $_.GetType().Name }) -join ' > '
                $failure = "threw $types, expected $($ExceptionType.Name): $($thrown.Message)"
                Assert-That -Condition $false -Message "$Message ($failure)"
                return
            }
        }

        foreach ($pattern in $MessageLike) {
            $wildcard = [WildcardPattern]::new($pattern, 'IgnoreCase, CultureInvariant')
            $matching = @($links.Where({ $wildcard.IsMatch($_.Message) }))
            if ($matching.Count -eq 0) {
                $messages = $links.ForEach({ $_.Message }) -join '; inner: '
                Assert-That -Condition $false -Message "$Message (message was: $messages)"
                return
            }
        }

        Assert-That -Condition $true -Message $Message
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
