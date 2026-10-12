#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a flat object as gh's --json output parses
$flat = '{"number":12,"headRefName":"feature","isDraft":false,"url":"https://x"}' | ConvertFrom-Json

# Act
$flatResult = ConvertTo-PascalCaseObject -InputObject $flat

# Assert
Assert-Equal -Expected @('Number', 'HeadRefName', 'IsDraft', 'Url') -Actual @($flatResult.PSObject.Properties.Name) `
    -Message 'Every camelCase property name is re-cased to PascalCase, in order'
Assert-Equal -Expected 12 -Actual $flatResult.Number -Message 'A number value is carried over unchanged'
Assert-Equal -Expected 'feature' -Actual $flatResult.HeadRefName -Message 'A string value is carried over unchanged'
Assert-Equal -Expected $false -Actual $flatResult.IsDraft -Message 'A bool value is carried over unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nested objects and an array of objects
$nested = '{"author":{"login":"octocat"},"labels":[{"name":"bug"},{"name":"docs"}]}' | ConvertFrom-Json

# Act
$nestedResult = ConvertTo-PascalCaseObject -InputObject $nested

# Assert
Assert-Equal -Expected 'octocat' -Actual $nestedResult.Author.Login -Message 'A nested object is re-cased too'
Assert-Equal -Expected 2 -Actual $nestedResult.Labels.Count -Message 'An array of objects keeps every element'
Assert-Equal -Expected 'docs' -Actual $nestedResult.Labels[1].Name -Message 'Each element of an array is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a top-level array of several elements, as a list command returns
$list = ConvertFrom-Json -InputObject '[{"tagName":"v1"},{"tagName":"v2"}]' -NoEnumerate

# Act
$listResult = ConvertTo-PascalCaseObject -InputObject $list

# Assert
Assert-Equal -Expected @('v1', 'v2') -Actual @($listResult.ForEach('TagName')) `
    -Message 'Each element of a top-level array is re-cased and written out one at a time'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same array, piped straight on
$piped = ConvertTo-PascalCaseObject -InputObject $list | Measure-Object

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each element is its own pipeline item, so the result pipes straight into another command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a top-level array of one element
$one = ConvertFrom-Json -InputObject '[{"tagName":"v1"}]' -NoEnumerate

# Act
$oneResult = ConvertTo-PascalCaseObject -InputObject $one

# Assert
Assert-That -Condition ($oneResult -isnot [array]) -Message 'A one-element array comes out as that one element'
Assert-Equal -Expected 'v1' -Actual $oneResult.TagName -Message 'and it is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array
$emptyResult = ConvertTo-PascalCaseObject -InputObject (ConvertFrom-Json -InputObject '[]' -NoEnumerate)

# Assert
Assert-That -Condition ($null -eq $emptyResult) -Message 'An empty array writes nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - -NoEnumerate keeps a top-level array whole
$wholeOne = ConvertTo-PascalCaseObject -InputObject $one -NoEnumerate
$wholeEmpty = ConvertTo-PascalCaseObject -InputObject (ConvertFrom-Json -InputObject '[]' -NoEnumerate) -NoEnumerate

# Assert
Assert-That -Condition ($wholeOne -is [array] -and $wholeOne.Count -eq 1) `
    -Message '-NoEnumerate returns a one-element array as an array'
Assert-Equal -Expected 'v1' -Actual $wholeOne[0].TagName -Message 'whose element is re-cased'
Assert-That -Condition ($wholeEmpty -is [array] -and $wholeEmpty.Count -eq 0) `
    -Message '-NoEnumerate returns an empty array as an empty array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - arrays inside an object, one with a single element and one empty
$inner = '{"labels":[{"name":"bug"}],"none":[],"nums":[1]}' | ConvertFrom-Json

# Act
$innerResult = ConvertTo-PascalCaseObject -InputObject $inner

# Assert
Assert-That -Condition ($innerResult.Labels -is [array] -and $innerResult.Labels.Count -eq 1) `
    -Message 'A one-element array inside an object stays an array'
Assert-Equal -Expected 'bug' -Actual $innerResult.Labels[0].Name -Message 'and its element is re-cased'
Assert-That -Condition ($innerResult.None -is [array] -and $innerResult.None.Count -eq 0) `
    -Message 'An empty array inside an object stays an empty array'
Assert-That -Condition ($innerResult.Nums -is [array] -and $innerResult.Nums.Count -eq 1) `
    -Message 'A one-element array of scalars stays an array too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - null values, as a REST response has for a missing body
$nulls = '{"body":null,"tags":[null,"x"]}' | ConvertFrom-Json

# Act
$nullResult = ConvertTo-PascalCaseObject -InputObject $nulls

# Assert
Assert-That -Condition ($nullResult.PSObject.Properties.Name -contains 'Body' -and $null -eq $nullResult.Body) `
    -Message 'A null property keeps its name and stays $null'
Assert-Equal -Expected 2 -Actual $nullResult.Tags.Count -Message 'A null inside an array is kept, not dropped'
Assert-That -Condition ($null -eq $nullResult.Tags[0]) -Message 'and is still null'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - scalars pass through untouched
Assert-Equal -Expected 'plain' -Actual (ConvertTo-PascalCaseObject -InputObject 'plain') `
    -Message 'A string is returned as-is'
Assert-Equal -Expected 7 -Actual (ConvertTo-PascalCaseObject -InputObject 7) -Message 'A number is returned as-is'
Assert-Equal -Expected 0 -Actual @(ConvertTo-PascalCaseObject -InputObject $null).Count -Message '$null writes nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a date value and a name that is already PascalCase
$typed = '{"createdAt":"2026-01-02T03:04:05Z","Already":"kept"}' | ConvertFrom-Json

# Act
$typedResult = ConvertTo-PascalCaseObject -InputObject $typed

# Assert
Assert-That -Condition ($typedResult.CreatedAt -is [datetime]) `
    -Message 'A date ConvertFrom-Json already typed stays a [datetime]'
Assert-Equal -Expected 'kept' -Actual $typedResult.Already -Message 'A property already in PascalCase is left alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - snake_case, as a raw REST response names its fields
$snake = '{"ref_name":"main","ruleset_id":123,"current_user_can_bypass":"never"}' | ConvertFrom-Json

# Act
$snakeResult = ConvertTo-PascalCaseObject -InputObject $snake

# Assert
Assert-Equal -Expected @('RefName', 'RulesetId', 'CurrentUserCanBypass') `
    -Actual @($snakeResult.PSObject.Properties.Name) `
    -Message 'Every underscore-separated segment is capitalized and joined with no separator'
Assert-Equal -Expected 'main' -Actual $snakeResult.RefName -Message 'The value is carried over unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a leading underscore, as GitHub's own "_links" field has
$leading = '{"_links":{"self":"https://x"}}' | ConvertFrom-Json

# Act
$leadingResult = ConvertTo-PascalCaseObject -InputObject $leading

# Assert
Assert-Equal -Expected @('Links') -Actual @($leadingResult.PSObject.Properties.Name) `
    -Message 'A leading underscore produces no empty leading segment'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an object keyed by file names, which are data and not field names
$gist = ConvertFrom-Json `
    -InputObject '{"id":"abc","created_at":"x","files":{"hello_world.py":{"file_name":"hello_world.py","raw_url":"u"},"README.md":{"size":1}}}'

# Act
$kept = ConvertTo-PascalCaseObject -InputObject $gist -KeepKeysOf 'files'
$default = ConvertTo-PascalCaseObject -InputObject $gist

# Assert
Assert-That -Condition ($kept.Files -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message '-KeepKeysOf returns a data-keyed object as an ordered dictionary'
Assert-Equal -Expected 'hello_world.py, README.md' -Actual (@($kept.Files.PSBase.Keys) -join ', ') `
    -Message 'with its keys exactly as they are'
Assert-Equal -Expected $null -Actual $kept.Files['readme.md'] -Message 'matched with their case'
Assert-Equal -Expected 'hello_world.py' -Actual $kept.Files.'hello_world.py'.FileName `
    -Message 'while what each holds is re-cased as usual'
Assert-Equal -Expected 'u' -Actual $kept.Files.'hello_world.py'.RawUrl -Message 'down through the nesting'
Assert-Equal -Expected 'x' -Actual $kept.CreatedAt -Message 'and the fields around it are re-cased too'
Assert-Equal -Expected 'HelloWorld.py, README.md' -Actual ($default.Files.PSObject.Properties.Name -join ', ') `
    -Message 'Without it, those keys are re-cased as any other'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same name at depth, in a list, and spelled in another case
$other = ConvertFrom-Json `
    -InputObject '{"items":[{"inner_object":{"files":{"a_b.txt":{"x_y":1}}}}],"Files":{"c_d.txt":1}}'

# Act
$deep = ConvertTo-PascalCaseObject -InputObject $other -KeepKeysOf 'files'

# Assert
Assert-Equal -Expected @('a_b.txt') -Actual @($deep.Items[0].InnerObject.Files.PSBase.Keys) `
    -Message 'A kept name is found at any depth, inside a list too'
Assert-Equal -Expected 1 -Actual $deep.Items[0].InnerObject.Files.'a_b.txt'.XY `
    -Message 'and what it holds is still re-cased'
Assert-Equal -Expected 'CD.txt' -Actual $deep.Files.PSObject.Properties.Name `
    -Message 'A name is matched with its case, so Files is re-cased when files is the one named'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a data key inside a kept object that equals the kept name
$nestedName = ConvertFrom-Json -InputObject '{"files":{"files":{"raw_url":"u"}}}'

# Act
$nestedResult = ConvertTo-PascalCaseObject -InputObject $nestedName -KeepKeysOf 'files'

# Assert
Assert-Equal -Expected @('files') -Actual @($nestedResult.Files.PSBase.Keys) `
    -Message 'A data key equal to the kept name stays as it is'
Assert-Equal -Expected 'u' -Actual $nestedResult.Files['files'].RawUrl `
    -Message 'but is data, not a kept name, so what it holds is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - keys that re-case to the same name, and one made only of underscores
$clash = ConvertFrom-Json -InputObject '{"a_b":1,"a__b":2,"_":3}'
$cased = ConvertFrom-Json -InputObject '{"foo_bar":1,"fooBar":2}'

# Act
$clashResult = ConvertTo-PascalCaseObject -InputObject $clash
$casedResult = ConvertTo-PascalCaseObject -InputObject $cased

# Assert
Assert-Equal -Expected @('AB', 'a__b', '_') -Actual @($clashResult.PSObject.Properties.Name) `
    -Message 'The later of two keys that re-case alike keeps its own name, and a key of underscores keeps its own'
Assert-Equal -Expected @(1, 2, 3) -Actual @($clashResult.AB, $clashResult.a__b, $clashResult.'_') `
    -Message 'and every value is kept'
Assert-That -Condition ($casedResult -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message 'Names a PSCustomObject cannot tell apart give an ordered dictionary'
Assert-Equal -Expected @('FooBar', 'fooBar') -Actual @($casedResult.PSBase.Keys) -Message 'with both keys in it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a hashtable, and a case-sensitive dictionary such as Invoke-GitHubApi can return
$table = @{ html_url = 'https://x'; nested = @{ node_id = 'n' } }
$exact = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
$exact['foo'] = 1
$exact['Foo'] = 2

# Act
$tableResult = ConvertTo-PascalCaseObject -InputObject $table
$exactResult = ConvertTo-PascalCaseObject -InputObject $exact

# Assert
Assert-Equal -Expected 'https://x' -Actual $tableResult.HtmlUrl -Message 'A hashtable is re-cased like any object'
Assert-Equal -Expected 'n' -Actual $tableResult.Nested.NodeId -Message 'down through the nesting'
Assert-Equal -Expected @('foo', 'Foo') -Actual @($exactResult.PSBase.Keys) `
    -Message 'Keys differing only in case each keep their own name'
Assert-Equal -Expected @(1, 2) -Actual @($exactResult['foo'], $exactResult['Foo']) -Message 'and their own value'

#───────────────────────────────────────────────────────────────────────────────
# Act - a dictionary with a key named keys, and a clash that sends it down the slow path
$shadowing = ConvertTo-PascalCaseObject -InputObject ([ordered]@{ keys = 'k'; foo_bar = 2; fooBar = 3 })

# Assert
Assert-Equal -Expected @('Keys', 'FooBar', 'fooBar') -Actual @($shadowing.PSBase.Keys) `
    -Message 'A key named keys is one key among the others, not the list of them'
Assert-Equal -Expected @('k', 2, 3) -Actual @($shadowing['Keys'], $shadowing['FooBar'], $shadowing['fooBar']) `
    -Message 'and every value is kept'

#───────────────────────────────────────────────────────────────────────────────
# Act - an object that is not a PSCustomObject or a dictionary
$uri = [uri]'https://example.com/'

# Assert
Assert-Equal -Expected $uri -Actual (ConvertTo-PascalCaseObject -InputObject $uri) `
    -Message 'Any other object is returned as it is'

#───────────────────────────────────────────────────────────────────────────────
# Act
$pipedOne = [PSCustomObject]@{ head_ref_name = 'feature' } | ConvertTo-PascalCaseObject

# Assert
Assert-Equal -Expected @('HeadRefName') -Actual @($pipedOne.PSObject.Properties.Name) `
    -Message 'An object piped in is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$list = @([PSCustomObject]@{ ref_name = 'a' }, [PSCustomObject]@{ ref_name = 'b' })

# Act
$pipedMany = @($list | ConvertTo-PascalCaseObject)

# Assert
Assert-Equal -Expected @('a', 'b') -Actual @($pipedMany.ForEach('RefName')) `
    -Message 'Objects piped in come out one at a time, each re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act
$pipedWhole = $list | ConvertTo-PascalCaseObject -NoEnumerate

# Assert
Assert-Equal -Expected 2 -Actual $pipedWhole.Count -Message 'With -NoEnumerate, objects piped in come back as one array'
Assert-That -Condition ($pipedWhole -is [array]) -Message 'that is an array'

#───────────────────────────────────────────────────────────────────────────────
# Act
$pipedNone = @(@() | ConvertTo-PascalCaseObject)

# Assert
Assert-Equal -Expected 0 -Actual $pipedNone.Count -Message 'An empty pipeline gives nothing'

exit (Complete-TestRun)
