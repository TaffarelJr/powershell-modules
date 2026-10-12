#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pretty-printed object across several lines, as gh emits it
$objectLines = @('{', '  "name": "repo",', '  "isPrivate": true', '}')

# Act
$object = ConvertFrom-GitHubJson -Line $objectLines

# Assert
Assert-Equal -Expected 'repo' -Actual $object.Name -Message 'A JSON object parses into one object'
Assert-Equal -Expected $true -Actual $object.IsPrivate -Message 'Property names are re-cased to PascalCase'

#───────────────────────────────────────────────────────────────────────────────
# Act - an array of several elements
$many = ConvertFrom-GitHubJson -Line @('[{"number": 1}, {"number": 2}]')

# Assert
Assert-Equal -Expected @(1, 2) -Actual @($many.ForEach('Number')) `
    -Message 'A JSON array comes out one element at a time, each re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same array, piped straight on
$piped = ConvertFrom-GitHubJson -Line @('[{"number": 1}, {"number": 2}]') | Measure-Object

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each element is its own pipeline item, so the result pipes straight into another command'

#───────────────────────────────────────────────────────────────────────────────
# Act - a one-element array
$single = ConvertFrom-GitHubJson -Line @('[{"number": 7}]')

# Assert
Assert-That -Condition ($single -isnot [array]) -Message 'A one-element JSON array comes out as that one element'
Assert-Equal -Expected 7 -Actual $single.Number -Message 'The one element is parsed and re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array
$empty = ConvertFrom-GitHubJson -Line @('[]')

# Assert
Assert-That -Condition ($null -eq $empty) -Message 'An empty JSON array writes nothing'
Assert-Equal -Expected 0 -Actual @(ConvertFrom-GitHubJson -Line @('[]')).Count `
    -Message 'so wrapping the call in @() collects an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Act - an array inside an object
$labelled = ConvertFrom-GitHubJson -Line @('{"labels": [{"name": "bug"}], "none": []}')

# Assert
Assert-That -Condition ($labelled.Labels -is [array]) -Message 'A one-element array inside an object stays an array'
Assert-That -Condition ($labelled.None -is [array] -and $labelled.None.Count -eq 0) -Message 'and so does an empty one'

#───────────────────────────────────────────────────────────────────────────────
# Act - -NoEnumerate keeps an array whole
$whole = ConvertFrom-GitHubJson -Line @('[{"number": 7}]') -NoEnumerate
$wholeEmpty = ConvertFrom-GitHubJson -Line @('[]') -NoEnumerate

# Assert
Assert-That -Condition ($whole -is [array] -and $whole.Count -eq 1) `
    -Message '-NoEnumerate returns a one-element array as an array'
Assert-Equal -Expected 7 -Actual $whole[0].Number -Message 'whose element is still re-cased'
Assert-That -Condition ($wholeEmpty -is [array] -and $wholeEmpty.Count -eq 0) `
    -Message '-NoEnumerate returns an empty array as an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Act - -NoEnumerate on something that is not an array
$wholeObject = ConvertFrom-GitHubJson -Line @('{"name": "repo"}') -NoEnumerate
$wholeNothing = ConvertFrom-GitHubJson -Line @() -NoEnumerate

# Assert
Assert-That -Condition ($wholeObject -isnot [array]) -Message '-NoEnumerate leaves a JSON object as an object'
Assert-That -Condition ($null -eq $wholeNothing) -Message 'and still writes nothing for no output'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - no output at all
Assert-Equal -Expected 0 -Actual @(ConvertFrom-GitHubJson -Line @()).Count -Message 'No output lines write nothing'
Assert-Equal -Expected 0 -Actual @(ConvertFrom-GitHubJson -Line @('', '  ')).Count `
    -Message 'Blank output lines write nothing'
Assert-Equal -Expected 0 -Actual @(ConvertFrom-GitHubJson -Line $null).Count `
    -Message 'A $null in place of the lines writes nothing'
Assert-Equal -Expected 0 -Actual @(ConvertFrom-GitHubJson -Line @('null')).Count -Message 'A JSON null writes nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - what a single line of output looks like to a caller that did not collect it
$oneLine = ConvertFrom-GitHubJson -Line '{"a": 1}'

# Assert
Assert-Equal -Expected 1 -Actual $oneLine.A -Message 'A single line, not an array of one, is accepted as the lines'

#───────────────────────────────────────────────────────────────────────────────
# Act - a raw API response, names kept as GitHub sent them
$kept = ConvertFrom-GitHubJson -Line @('{"default_branch":"main","html_url":"https://x"}') -KeepFieldNames

# Assert
Assert-Equal -Expected 'main' -Actual $kept.default_branch -Message '-KeepFieldNames leaves a snake_case name untouched'
Assert-Equal -Expected @('default_branch', 'html_url') -Actual @($kept.PSObject.Properties.Name) `
    -Message '-KeepFieldNames re-cases nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - -KeepFieldNames with -NoEnumerate, as Invoke-GitHubApi asks for
$keptList = ConvertFrom-GitHubJson -Line @('[{"html_url":"https://x"}]') -KeepFieldNames -NoEnumerate

# Assert
Assert-That -Condition ($keptList -is [array] -and $keptList.Count -eq 1) `
    -Message '-KeepFieldNames and -NoEnumerate together keep the array whole'
Assert-Equal -Expected 'https://x' -Actual $keptList[0].html_url -Message 'with the names untouched'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - output that is not JSON
Assert-Throws -ScriptBlock {
    ConvertFrom-GitHubJson -Line @('Welcome to the', 'GitHub CLI')
} -MessageLike "*gh's output is not valid JSON*Welcome to the*GitHub CLI*" `
    -Message 'Output that is not JSON throws, showing what it was'
Assert-Throws -ScriptBlock {
    ConvertFrom-GitHubJson -Line @('{"a":')
} -ExceptionType ([System.IO.InvalidDataException]) `
    -Message 'and throws it as InvalidDataException, so a caller can tell it from any other failure'

# Act
$long = 'x' * 500

# Assert
Assert-Throws -ScriptBlock {
    ConvertFrom-GitHubJson -Line @($long)
} -MessageLike "*not valid JSON*$('x' * 120)...*" -Message 'A long output is cut to a look at its start'

#───────────────────────────────────────────────────────────────────────────────
# Act - strings that look like dates, under keys that are not a date's
$texts = ConvertFrom-GitHubJson -Line @('{"title":"2024-01-02T03:04:05Z","format":"2024-01-02T03:04:05+05:00"}')

# Assert
Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $texts.Title `
    -Message 'A string stays a string, however much it looks like a timestamp'
Assert-Equal -Expected '2024-01-02T03:04:05+05:00' -Actual $texts.Format `
    -Message 'and a key ending in a lower-case "at" is not a date''s'

#───────────────────────────────────────────────────────────────────────────────
# Act - timestamps under keys ending At, _at, and Date
$dated = ConvertFrom-GitHubJson -Line @(
    '{"createdAt":"2024-01-02T03:04:05Z","updated_at":"2024-01-02T03:04:05+05:00",'
    '"dueDate":"2024-01-02T03:04:05.5Z","closedAt":"not a time","mergedAt":null}'
)

# Assert
Assert-Equal -Expected ([datetime]::new(2024, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)) -Actual $dated.CreatedAt `
    -Message 'A UTC timestamp under a key ending At is a [datetime]'
Assert-Equal -Expected ([DateTimeKind]::Utc) -Actual $dated.CreatedAt.Kind -Message 'of Kind Utc'
Assert-Equal -Expected ([DateTimeOffset]::Parse('2024-01-02T03:04:05+05:00').LocalDateTime) -Actual $dated.UpdatedAt `
    -Message 'One with an offset, under a key ending _at, is that moment in local time'
Assert-Equal -Expected ([DateTimeKind]::Local) -Actual $dated.UpdatedAt.Kind -Message 'of Kind Local'
Assert-Equal -Expected ([datetime]::new(2024, 1, 2, 3, 4, 5, 500, [DateTimeKind]::Utc)) -Actual $dated.DueDate `
    -Message 'A key ending Date is a date''s too, fraction and all'
Assert-Equal -Expected 'not a time' -Actual $dated.ClosedAt `
    -Message 'Text that is not a timestamp stays text, whatever its key'
Assert-Equal -Expected $null -Actual $dated.MergedAt -Message 'and a null stays $null'

#───────────────────────────────────────────────────────────────────────────────
# Act - Go's zero time, which gh writes for a time that was never set
$open = ConvertFrom-GitHubJson -Line @('{"closedAt":"0001-01-01T00:00:00Z","state":"OPEN"}')

# Assert
Assert-Equal -Expected @('ClosedAt', 'State') -Actual @($open.PSObject.Properties.Name) `
    -Message 'A year-0001 timestamp keeps its property'
Assert-Equal -Expected $null -Actual $open.ClosedAt -Message 'whose value is $null, not a date that reads as true'

#───────────────────────────────────────────────────────────────────────────────
# Act - numbers and literals
$values = ConvertFrom-GitHubJson `
    -Line @('{"count":7,"ratio":1.5,"huge":123456789012345678901234,"vast":1e400,"yes":true,"no":false}')

# Assert
Assert-Equal -Expected ([long]7) -Actual $values.Count -Message 'A whole number is a [long]'
Assert-That -Condition ($values.Count -is [long]) -Message 'of that type exactly'
Assert-Equal -Expected 1.5D -Actual $values.Ratio -Message 'A fraction is a [decimal], exactly as written'
Assert-Equal -Expected 123456789012345678901234D -Actual $values.Huge `
    -Message 'and so is a whole number too large for a [long]'
Assert-Equal -Expected '1e400' -Actual $values.Vast `
    -Message 'A number too large even for a [double] stays its text rather than becoming infinity'
Assert-Equal -Expected @($true, $false) -Actual @($values.Yes, $values.No) -Message 'true and false are bools'

#───────────────────────────────────────────────────────────────────────────────
# Act - a bare JSON value at the top
$text = ConvertFrom-GitHubJson -Line @('"just text"')
$number = ConvertFrom-GitHubJson -Line @('42')

# Assert
Assert-Equal -Expected 'just text' -Actual $text -Message 'A bare JSON string is returned as the string'
Assert-Equal -Expected ([long]42) -Actual $number -Message 'and a bare number as the number'

#───────────────────────────────────────────────────────────────────────────────
# Act - arrays of arrays
$nested = ConvertFrom-GitHubJson -Line @('[[1,2],[],["x"]]') -NoEnumerate

# Assert
Assert-Equal -Expected 3 -Actual $nested.Count -Message 'An array of arrays keeps every inner array'
Assert-That -Condition ($nested[1] -is [array] -and $nested[1].Count -eq 0) -Message 'an empty one included'
Assert-That -Condition ($nested[2] -is [array] -and $nested[2].Count -eq 1) `
    -Message 'and a one-element one stays an array'

#───────────────────────────────────────────────────────────────────────────────
# Act - two keys that re-case to the same name
$clash = ConvertFrom-GitHubJson -Line @('{"a_b":1,"a__b":2,"x":3}')

# Assert
Assert-Equal -Expected @('AB', 'a__b', 'X') -Actual @($clash.PSObject.Properties.Name) `
    -Message 'The later of two keys that re-case alike keeps its own name, so nothing is dropped'
Assert-Equal -Expected @(1, 2) -Actual @($clash.AB, $clash.a__b) -Message 'and each keeps its own value'

#───────────────────────────────────────────────────────────────────────────────
# Act - keys a PSCustomObject cannot hold: two differing only in case
$cased = ConvertFrom-GitHubJson -Line @('{"foo_bar":1,"fooBar":2}')
$files = ConvertFrom-GitHubJson -Line @('{"README.md":1,"readme.md":2}') -KeepFieldNames

# Assert
Assert-That -Condition ($cased -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message 'An object whose names differ only in case comes back as an ordered dictionary'
Assert-Equal -Expected @('FooBar', 'fooBar') -Actual @($cased.PSBase.Keys) `
    -Message 'with the later of two clashing keys under its own name'
Assert-Equal -Expected @(1, 2) -Actual @($cased.FooBar, $cased.fooBar) -Message 'read case-sensitively by name'
Assert-Equal -Expected @(1, 2) -Actual @($files['README.md'], $files['readme.md']) `
    -Message 'Keys kept as they are survive a difference in case alone'
Assert-Equal -Expected $null -Actual $files['Readme.md'] -Message 'and are matched with their case'

#───────────────────────────────────────────────────────────────────────────────
# Act - a later key whose own name is what an earlier one re-cased to
$sameName = ConvertFrom-GitHubJson -Line @('{"foo":1,"Foo":2,"a_b":3,"AB":4}')

# Assert
Assert-Equal -Expected @('foo', 'Foo', 'a_b', 'AB') -Actual @($sameName.PSBase.Keys) `
    -Message 'Each of two such keys keeps its own name, so neither value is lost'
Assert-Equal -Expected @(1, 2, 3, 4) -Actual @($sameName['foo'], $sameName['Foo'], $sameName['a_b'], $sameName['AB']) `
    -Message 'and its own value'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty key, a reserved one, and one made only of underscores
$empty = ConvertFrom-GitHubJson -Line @('{"":1,"a":2}') -KeepFieldNames
$reserved = ConvertFrom-GitHubJson -Line @('{"PSObject":1,"psbase":2}') -KeepFieldNames
$underscore = ConvertFrom-GitHubJson -Line @('{"_":1}')

# Assert
Assert-Equal -Expected @(1, 2) -Actual @($empty[''], $empty['a']) -Message 'An empty key survives, in a dictionary'
Assert-Equal -Expected @('PSObject', 'psbase') -Actual @($reserved.PSBase.Keys) `
    -Message 'and so does a name PowerShell reserves'
Assert-Equal -Expected @('_') -Actual @($underscore.PSObject.Properties.Name) `
    -Message 'A key that re-cases to nothing keeps its own name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a key the JSON gives twice in one object, with and without re-casing
$repeats = @(
    @{
        Json = '{"a":1,"a":2}'
        KeepFieldNames = $true
        Key = 'a'
        Message = 'A key given twice throws instead of losing a value, with -KeepFieldNames'
    }
    @{
        Json = '{"a":1,"a":2}'
        KeepFieldNames = $false
        Key = 'a'
        Message = 'and without it, though the second could have kept its own name'
    }
    @{
        Json = '{"foo_bar":1,"foo_bar":2}'
        KeepFieldNames = $false
        Key = 'foo_bar'
        Message = 'and for a key that re-cases'
    }
    @{
        Json = '{"x":{"b":1,"c":2,"b":3}}'
        KeepFieldNames = $false
        Key = 'b'
        Message = 'at any depth, wherever the repeat comes'
    }
    @{
        Json = '{"files":{"a.txt":1,"a.txt":2}}'
        KeepFieldNames = $false
        Key = 'a.txt'
        Message = 'and in an object keyed by data'
    }
)

# Act / Assert
foreach ($case in $repeats) {
    Assert-Throws -ScriptBlock {
        ConvertFrom-GitHubJson -Line @($case.Json) -KeepFieldNames:$case.KeepFieldNames -KeepKeysOf 'files'
    } -MessageLike "A JSON object gives the key '$($case.Key)' twice, and one of its values would be lost." `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - an object with keys named Keys and Values, and a clash that sends it down the slow path
$shadowing = ConvertFrom-GitHubJson -Line @('{"keys":1,"foo":2,"Foo":3}')
$shadowingKept = ConvertFrom-GitHubJson -Line @('{"Keys":1,"keys":2,"values":3}') -KeepFieldNames
$shadowingValues = ConvertFrom-GitHubJson -Line @('{"values":"v","Keys":"K","psobject":1}')

# Assert
Assert-Equal -Expected @('Keys', 'foo', 'Foo') -Actual @($shadowing.PSBase.Keys) `
    -Message 'A key named keys is one key among the others, not the list of them'
Assert-Equal -Expected @(1, 2, 3) -Actual @($shadowing['Keys'], $shadowing['foo'], $shadowing['Foo']) `
    -Message 'and every value is kept'
Assert-Equal -Expected @('Keys', 'keys', 'values') -Actual @($shadowingKept.PSBase.Keys) `
    -Message 'with -KeepFieldNames too'
Assert-Equal -Expected @(1, 2, 3) -Actual @($shadowingKept['Keys'], $shadowingKept['keys'], $shadowingKept['values']) `
    -Message 'each with its own value'
Assert-Equal -Expected @('Values', 'Keys', 'Psobject') -Actual @($shadowingValues.PSBase.Keys) `
    -Message 'A key named values is one key too'
Assert-Equal -Expected @('v', 'K', 1) `
    -Actual @($shadowingValues['Values'], $shadowingValues['Keys'], $shadowingValues['Psobject']) `
    -Message 'with its own value'

#───────────────────────────────────────────────────────────────────────────────
# Act - timestamps that match the pattern but name no time .NET can hold
$impossible = ConvertFrom-GitHubJson `
    -Line @('{"lastAt":"2024-02-30T00:00:00Z","leapAt":"2016-12-31T23:59:60Z","farAt":"9999-12-31T23:59:59-14:00","okAt":"2024-02-29T00:00:00Z"}')

# Assert
Assert-Equal -Expected @('2024-02-30T00:00:00Z', '2016-12-31T23:59:60Z', '9999-12-31T23:59:59-14:00') `
    -Actual @($impossible.LastAt, $impossible.LeapAt, $impossible.FarAt) `
    -Message 'February 30, a leap second, and a time past year 9999 stay their text, and the rest of the response is kept'
Assert-Equal -Expected ([datetime]::new(2024, 2, 29, 0, 0, 0, [DateTimeKind]::Utc)) -Actual $impossible.OkAt `
    -Message 'while a real date beside them is still a [datetime]'

#───────────────────────────────────────────────────────────────────────────────
# Act - deep nesting, as ConvertFrom-Json allows
$deep = ConvertFrom-GitHubJson -Line @(('[' * 100) + '7' + (']' * 100)) -NoEnumerate
$level = $deep
foreach ($step in 1..99) {
    $level = $level[0]
}

# Assert
Assert-Equal -Expected @([long]7) -Actual $level -Message 'An array nested 100 deep is read to the bottom'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - nesting past the limit
Assert-Throws -ScriptBlock {
    ConvertFrom-GitHubJson -Line @(('[' * 1100) + (']' * 1100))
} -MessageLike "gh's output is not valid JSON, starting '``[``[``[*': *depth of 1024 has been exceeded*." `
    -Message 'and nesting past 1024 is not valid JSON, as for ConvertFrom-Json'

#───────────────────────────────────────────────────────────────────────────────
# Act - an object keyed by file names
$gist = ConvertFrom-GitHubJson -Line @(
    '{"id":"abc","files":{"hello_world.py":{"raw_url":"u","size":1},"README.md":{"size":2},'
    '"readme.md":{"size":3},"PSObject":{"size":4},"x_at":{"size":5}}}'
) -KeepKeysOf 'files'

# Assert
Assert-That -Condition ($gist.Files -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message '-KeepKeysOf returns the data-keyed object as an ordered dictionary'
Assert-Equal -Expected @('hello_world.py', 'README.md', 'readme.md', 'PSObject', 'x_at') `
    -Actual @($gist.Files.PSBase.Keys) `
    -Message 'with every key exactly as it was, in order'
Assert-Equal -Expected 'u' -Actual $gist.Files.'hello_world.py'.RawUrl `
    -Message 'read by name, with what each key holds re-cased as usual'
Assert-Equal -Expected 3 -Actual $gist.Files['readme.md'].Size `
    -Message 'or by index, telling apart keys that differ only in case'
Assert-Equal -Expected $null -Actual $gist.Files['Hello_World.py'] -Message 'and matching with case'
Assert-Equal -Expected 'abc' -Actual $gist.Id -Message 'while the fields around it are re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - a data key that equals the kept name, and the kept name in another case
$inner = ConvertFrom-GitHubJson -Line @('{"files":{"files":{"raw_url":"u"}},"Files":{"c_d":1}}') -KeepKeysOf 'files'
$dataDate = ConvertFrom-GitHubJson -Line @('{"files":{"created_at":"2024-01-02T03:04:05Z"}}') -KeepKeysOf 'files'

# Assert
Assert-Equal -Expected 'u' -Actual $inner.files['files'].RawUrl `
    -Message 'A data key that happens to equal the kept name is data, so what it holds is still re-cased'
Assert-Equal -Expected @('CD') -Actual @($inner.Files.PSObject.Properties.Name) `
    -Message 'A kept name is matched with its case'
Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $dataDate.Files['created_at'] `
    -Message 'and a data key is never read as a date''s'

#───────────────────────────────────────────────────────────────────────────────
# Act - the plural name -Line had before, which stays an alias
$byAlias = ConvertFrom-GitHubJson -Lines @('{"name": "repo"}')
$aliases = (Get-Command -Name ConvertFrom-GitHubJson).Parameters['Line'].Aliases

# Assert
Assert-Equal -Expected 'repo' -Actual $byAlias.Name -Message '-Lines still parses the lines'
Assert-Equal -Expected @('Lines') -Actual @($aliases) -Message 'as the alias of -Line'

#───────────────────────────────────────────────────────────────────────────────
# Act
$piped = '{"head_ref_name":"feature"}' | ConvertFrom-GitHubJson

# Assert
Assert-Equal -Expected 'feature' -Actual $piped.HeadRefName -Message 'A line piped in is parsed'

#───────────────────────────────────────────────────────────────────────────────
# Act - a pretty-printed array, one line at a time, as Invoke-GitHubCommand writes it
$pipedLines = @('[', '  {"number": 1},', '  {"number": 2}', ']') | ConvertFrom-GitHubJson

# Assert
Assert-Equal -Expected @(1, 2) -Actual @($pipedLines.ForEach('Number')) `
    -Message 'Lines piped in are gathered and parsed as one document'

#───────────────────────────────────────────────────────────────────────────────
# Act
$pipedNone = @(@() | ConvertFrom-GitHubJson)

# Assert
Assert-Equal -Expected 0 -Actual $pipedNone.Count -Message 'An empty pipeline gives nothing'

exit (Complete-TestRun)
