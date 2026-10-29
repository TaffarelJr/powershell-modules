using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Management.Automation

function ConvertTo-GitHubSearchArgument {
    <#
    .SYNOPSIS
        Builds the arguments for a gh search command from a search
        function's own parameters.
    .DESCRIPTION
        Each parameter that was passed and has an entry in -Flag becomes
        that gh flag, in the order -Flag lists them. A switch is the bare
        flag, or flag=false in one argument when passed as false, as gh
        reads a separate false as a search keyword. A list is one flag per
        value, and anything else is the flag and its value. A value of a
        parameter with a ValidateSet is sent in lower case: gh passes it
        on as given, and GitHub ignores a sort or order it does not
        recognize. Each value for --repo is cut down to OWNER/REPO by
        ConvertTo-GitHubSearchRepository.

        A filter that was passed but is empty, blank, or $null throws, as does a
        blank keyword: leaving it out would widen the search, as far as
        all of GitHub. A list value holding a comma throws too, because gh
        splits it into two filters. With no keyword and no filter that
        narrows the search, it throws rather than search all of GitHub;
        the options that only shape the results or pick a state, and
        every switch, do not count as narrowing it.

        The query goes last, after a --, so one that starts with a dash -
        -label:bug excludes - is read as a query and not as an option.
    .PARAMETER Subcommand
        The gh search subcommand: code, commits, issues, prs or repos.
    .PARAMETER JsonFields
        The comma-separated fields to ask gh for.
    .PARAMETER Command
        The calling function, whose ValidateSet parameters are sent in
        lower case.
    .PARAMETER Bound
        The calling function's $PSBoundParameters.
    .PARAMETER Flag
        An ordered map from a parameter's name to its gh flag.
    .PARAMETER Date
        The parameters that take a date. A [datetime] or [datetimeoffset]
        at midnight is sent as the day it shows, yyyy-MM-dd, with no shift
        to UTC, as it is a calendar date; one with a time of day throws,
        as GitHub would match it to the exact second. Text is sent as
        given.
    .PARAMETER PresentOnly
        The switches gh ignores when set to false, so passing one as false
        throws instead of filtering nothing.
    .PARAMETER FalseKeyword
        A map from a switch's name to the keyword that asks for its false
        form, for a switch whose flag=false gh ignores.
    .PARAMETER Query
        The search keywords, each one argument. When -Bound holds a Query
        too, it must hold at least one keyword.
    .OUTPUTS
        The arguments, one at a time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Subcommand,

        [Parameter(Mandatory)]
        [string]$JsonFields,

        [Parameter(Mandatory)]
        [CommandInfo]$Command,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Bound,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.IOrderedDictionary]$Flag,

        [string[]]$Date,

        [string[]]$PresentOnly,

        [System.Collections.IDictionary]$FalseKeyword,

        [string[]]$Query
    )

    $notNarrowing = @(
        'Limit', 'Sort', 'Order', 'SearchType', 'Match', 'IncludePullRequests', 'IncludeForks', 'Visibility',
        'State', 'Archived', 'Merged', 'Draft', 'Locked', 'Merge', 'NoLabel', 'NoMilestone', 'NoAssignee',
        'NoProject', 'Checks', 'Review'
    )
    $arguments = [List[string]]::new()
    $arguments.AddRange([string[]]@('search', $Subcommand, '--json', $JsonFields))
    $keywords = [List[string]]::new()
    $narrowed = $false

    foreach ($name in $Flag.PSBase.Keys) {
        if (-not $Bound.ContainsKey($name)) {
            continue
        }

        $value = $Bound[$name]
        $flagName = $Flag[$name]
        $sets = @($Command.Parameters[$name].Attributes | Where-Object { $_ -is [ValidateSetAttribute] })
        $lowerCase = $sets.Count -gt 0
        $blank = "-$name was given but is blank, so it would filter nothing and the search would " +
            "widen, as far as all of GitHub. Give a value, or leave -$name off."
        if ($notNarrowing -notcontains $name) {
            $narrowed = $true
        }

        if ($value -is [SwitchParameter]) {
            if ($value.IsPresent) {
                $arguments.Add($flagName)
            }
            elseif ($PresentOnly -contains $name) {
                throw "-${name}:`$false filters nothing: gh ignores $flagName=false, as this filter has no " +
                    "false form. Leave -$name off instead."
            }
            elseif ($null -ne $FalseKeyword -and $FalseKeyword.Contains($name)) {
                $keywords.Add($FalseKeyword[$name])
            }
            else {
                $arguments.Add("$flagName=false")
            }
        }
        elseif ($null -eq $value) {
            throw "-$name was given, but it is `$null, so it would filter nothing and the search would " +
                "widen, as far as all of GitHub. Give a value, or leave -$name off."
        }
        elseif ($Date -contains $name -and ($value -is [datetime] -or $value -is [datetimeoffset])) {
            $day = if ($value -is [datetimeoffset]) { $value.DateTime } else { $value }
            if ($day.TimeOfDay -ne [timespan]::Zero) {
                throw "-$name got a date with a time of day, which GitHub matches to the exact second. " +
                    "Give a date (.Date), or text such as '>=2026-10-11T09:33:17Z'."
            }

            $arguments.AddRange([string[]]@($flagName, $day.ToString('yyyy-MM-dd', [CultureInfo]::InvariantCulture)))
        }
        elseif ($Date -contains $name -and $value -isnot [string]) {
            throw "-$name takes one date or date range, as a [datetime], a [datetimeoffset], or text such " +
                "as '2026-01-01..2026-01-31' or '>2026-01-01', not a $($value.GetType().Name)."
        }
        elseif ($value -is [array]) {
            if ($value.Count -eq 0) {
                throw "-$name was given but is empty, so it would filter nothing and the search would " +
                    "widen, as far as all of GitHub. Give at least one value, or leave -$name off."
            }

            foreach ($item in $value) {
                if ([string]::IsNullOrWhiteSpace($item) -and $value.Count -eq 1) {
                    throw $blank
                }

                if ([string]::IsNullOrWhiteSpace($item)) {
                    throw "-$name holds a blank value, which would filter nothing. Give only real values."
                }

                if ($item -is [string] -and $item.Contains(',')) {
                    $shownItem = Hide-UrlCredential -Text $item
                    throw "-$name value '$shownItem' holds a comma, and gh would split it into two filters. " +
                        "Give each value on its own (-$name 'a', 'b'); for one value that holds a comma, " +
                        "put the qualifier in -Query instead, quoted, such as 'label:`"a,b`"'."
                }

                $text = if ($flagName -eq '--repo') {
                    ConvertTo-GitHubSearchRepository -Repository $item
                }
                elseif ($lowerCase) {
                    $item.ToLowerInvariant()
                }
                else {
                    [string]$item
                }

                $arguments.AddRange([string[]]@($flagName, $text))
            }
        }
        else {
            $text = [string]$value
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw $blank
            }

            if ($lowerCase) {
                $text = $text.ToLowerInvariant()
            }

            $arguments.AddRange([string[]]@($flagName, $text))
        }
    }

    if ($Bound.ContainsKey('Query') -and ($null -eq $Query -or $Query.Count -eq 0)) {
        throw '-Query was given but holds no keyword, which searches for nothing. Give a keyword, or leave ' +
            '-Query off.'
    }

    $queryWords = @(foreach ($word in $Query) {
            if ([string]::IsNullOrWhiteSpace($word)) {
                throw '-Query holds a blank keyword, which searches for nothing. Give only real keywords.'
            }

            $word
        })

    if ($queryWords.Count -eq 0 -and -not $narrowed) {
        throw 'Give a query or at least one filter: with neither, the search would cover all of GitHub. ' +
            'Options that only shape the results or pick a state do not narrow it: -Limit, -Sort, -Order, ' +
            '-Match, -SearchType, -State, -Checks, -Review, -Visibility, -IncludeForks, -IncludePullRequests, ' +
            'and the switches ' +
            '-Archived, -Merged, -Draft, -Locked, -Merge, -NoLabel, -NoMilestone, -NoAssignee, and -NoProject.'
    }

    $queryWords += @($keywords)

    if ($queryWords.Count -gt 0) {
        $arguments.Add('--')
        $arguments.AddRange([string[]]$queryWords)
    }

    return $arguments.ToArray()
}
