function ConvertTo-PascalCaseObject {
    <#
    .SYNOPSIS
        Returns a copy of an already-parsed JSON value with every property
        name re-cased to PascalCase, recursively.
    .DESCRIPTION
        gh's own --json output names fields in camelCase
        (headRefName, isDraft); a raw REST response names them in
        snake_case instead (ref_name, created_at). PowerShell objects
        name their properties in PascalCase (HeadRefName, CreatedAt), as
        every other module here does - so each underscore-separated
        segment is capitalized on its own before being joined back
        together, which leaves a plain camelCase name's single segment
        exactly as a bare "uppercase the first letter" pass would. A key
        made only of underscores keeps its own name.

        For a value parsed elsewhere - typically Invoke-GitHubApi's, which
        keeps GitHub's own names. Text straight from gh goes through
        ConvertFrom-GitHubJson instead, which parses and re-cases in one
        pass. Both follow the same rules: two keys that come out with the
        same name keep the first under the new name and the later one
        under its own, and an object whose names a PSCustomObject cannot
        hold comes back as a case-sensitive ordered dictionary. A
        dictionary's keys are read with .PSBase.Keys, so a key named Keys
        is data like any other.

        An object is a PSCustomObject or a dictionary (a hashtable
        included); either comes back re-cased. A string, number, bool, or
        date is returned as it is, and so is any other object.

        An array comes out one element at a time, like any cmdlet's list.
        An array inside an object stays an array however many elements it
        has.

        Some objects are keyed by data, not by field name - a gist's
        'files', keyed by file name. Re-casing those keys would turn
        'hello_world.py' into 'HelloWorld.py', so -KeepKeysOf names them.
    .PARAMETER InputObject
        The value to re-case, typically Invoke-GitHubApi's output. Accepted
        from the pipeline: the values piped in are gathered, and re-cased as
        one array when there are several, one at a time as they come out.
    .PARAMETER NoEnumerate
        Returns an array as one array instead of writing its elements out
        one by one, as ConvertFrom-Json's own -NoEnumerate does. For a
        caller that keeps the result as a value, such as a property's.
    .PARAMETER KeepKeysOf
        Names of properties whose value is keyed by data. That value comes
        back as a case-sensitive ordered dictionary with its keys exactly
        as they are, so $files.'a.txt' and $files['a.txt'] both read one;
        what each key holds is re-cased as usual. Names are matched as they
        arrive, before any re-casing, with case, at any depth, but never
        against a key inside such a dictionary, since that key is data too.
        List such a dictionary with $files.PSBase.Keys and
        $files.PSBase.Values, never with $files.Keys and $files.Values: a
        file named Keys or Values would answer those instead.
    .INPUTS
        System.Object
        The values to re-case.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The same shape as the input, with PascalCase property names: the
        elements of an array one at a time, and nothing for $null.
    .EXAMPLE
        $raw = Invoke-GitHubApi 'gists/abc123'
        $gist = ConvertTo-PascalCaseObject -InputObject $raw -KeepKeysOf 'files'

        Re-cases a raw REST response (html_url becomes HtmlUrl) while every
        file name under Files stays exactly as GitHub sent it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [switch]$NoEnumerate,

        [string[]]$KeepKeysOf
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $gathered = [System.Collections.Generic.List[object]]::new()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $gathered.Add($InputObject)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            if ($gathered.Count -eq 0) {
                return
            }

            # Assigned, not emitted, so a value that is itself an array stays one.
            $value = $gathered[0]
            if ($gathered.Count -gt 1) {
                $value = $gathered.ToArray()
            }

            $context = New-GitHubJsonContext -KeepFieldNames $false -KeepKeysOf $KeepKeysOf
            $result = ConvertTo-PascalCaseNode -Node $value -Context $context
            if ($null -eq $result) {
                return
            }

            if ($result -is [array] -and $NoEnumerate) {
                return , $result
            }

            return $result
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
