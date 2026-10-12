using namespace System.IO
using namespace System.Text.Json

function ConvertFrom-GitHubJson {
    <#
    .SYNOPSIS
        Parses gh's JSON output lines into objects with PascalCase
        property names.
    .DESCRIPTION
        The lines are parsed as one document with System.Text.Json and
        converted in a single pass: property names are re-cased from
        camelCase or snake_case to PascalCase (headRefName and
        head_ref_name both become HeadRefName) unless -KeepFieldNames says
        otherwise. A JSON array comes out one element at a time, like any
        cmdlet's list; -NoEnumerate keeps it whole, as ConvertFrom-Json's
        own -NoEnumerate does.

        Values keep their JSON types. A string stays a string, whatever it
        looks like - an issue title that happens to be a timestamp is still
        its text. Only under a key ending in At, _at, or Date (createdAt,
        updated_at, dueDate) is an ISO 8601 timestamp a [datetime]: Kind
        Utc for one ending Z, local time for one with an offset, and $null
        for year 0001, which gh writes for a time that was never set; a
        time that cannot be a [datetime], such as February 30 or a leap
        second, stays its text. A whole number that fits is a [long], other
        numbers a [decimal], then a [double]; one too large even for that
        stays its text. True and false are bools, and null is $null.
        Objects may nest 1024 deep, as ConvertFrom-Json allows.

        Keys are read case-sensitively, so nothing in the JSON is lost. Two
        keys that come out with the same name - foo_bar and fooBar - keep
        the first under the new name and the later one under its own; when
        the later one's own name is the new name - foo, then Foo - each
        keeps its own. An object whose names a PSCustomObject cannot hold -
        two differing only in case, an empty one, or a reserved one such as
        PSObject - comes back as a case-sensitive ordered dictionary
        instead, which reads the same way ($object.Name or
        $object['Name']). A key the JSON gives twice in one object throws,
        with or without -KeepFieldNames, as ConvertFrom-Json does.
    .PARAMETER Line
        gh's output lines, as Invoke-GitHubCommand returns them. Nothing
        at all, one line, or many are all fine. Accepted from the pipeline:
        the lines piped in are gathered, then parsed as one document.
    .PARAMETER KeepFieldNames
        Leaves property names exactly as the JSON had them. For a raw API
        response, whose snake_case names are GitHub's documented contract.
    .PARAMETER NoEnumerate
        Returns a JSON array as one array, however many elements it has,
        instead of writing them out one by one. For a caller that has to
        tell an array from a single object.
    .PARAMETER KeepKeysOf
        Names of properties whose value is keyed by data rather than by
        field name - a gist's 'files', keyed by file name. That value comes
        back as a case-sensitive ordered dictionary with its keys exactly
        as they are, so $files.'a.txt' and $files['a.txt'] both read one;
        what each key holds is converted as usual. Names are matched as the
        JSON has them, with case, at any depth, but never against a key
        inside such a dictionary, since that key is data too. List such a
        dictionary with $files.PSBase.Keys and $files.PSBase.Values, never
        with $files.Keys and $files.Values: a file named Keys or Values
        would answer those instead.
    .INPUTS
        System.String
        gh's output lines.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        An object for a JSON object (an ordered dictionary instead when a
        PSCustomObject cannot hold its names); the elements of a JSON
        array, one at a time; a string, number, or bool for a bare JSON
        value. Nothing when there was no output, or the JSON was null.
    .EXAMPLE
        $lines = Invoke-GitHubCommand -Activity 'Reading the gist' `
            -Argument @('api', 'gists/abc123')
        $files = (ConvertFrom-GitHubJson -Line $lines -KeepKeysOf 'files').Files

        Reads a gist with its file names intact: $files['README.md'] and
        $files['readme.md'] are two different files, each with its own
        Filename, Size, and Content.
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
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [Alias('Lines')]
        [AllowEmptyString()]
        [string[]]$Line,

        [switch]$KeepFieldNames,

        [switch]$NoEnumerate,

        [string[]]$KeepKeysOf
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $gathered = [System.Collections.Generic.List[string]]::new()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            foreach ($item in $Line) {
                $gathered.Add($item)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            $text = ($gathered -join "`n").Trim()
            if (-not $text) {
                return
            }

            try {
                $document = [JsonDocument]::Parse($text, [JsonDocumentOptions]@{ MaxDepth = 1024 })
            }
            catch {
                # Hidden before the cut, so a credential the cut would split is still seen whole.
                $head = if ($text.Length -gt 1024) { $text.Substring(0, 1024) } else { $text }
                $shown = Hide-GitHubCredential -Text $head
                $preview = if ($shown.Length -gt 120) { $shown.Substring(0, 120) + '...' } else { $shown }
                $reason = $_.Exception.GetBaseException().Message.TrimEnd('.')
                $message = "gh's output is not valid JSON, starting '$preview': $reason."
                throw [InvalidDataException]::new($message, $_.Exception)
            }

            try {
                $context = New-GitHubJsonContext -KeepFieldNames $KeepFieldNames -KeepKeysOf $KeepKeysOf
                $root = $document.RootElement
                $result = switch ($root.ValueKind) {
                    'Object' {
                        ConvertFrom-GitHubJsonObject -Element $root -Context $context
                    }
                    'Array' {
                        , (ConvertFrom-GitHubJsonArray -Element $root -Context $context)
                    }
                    default {
                        ConvertFrom-GitHubJsonScalar -Element $root
                    }
                }
            }
            finally {
                $document.Dispose()
            }

            if ($null -eq $result) {
                return
            }

            if ($NoEnumerate -and $result -is [array]) {
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
