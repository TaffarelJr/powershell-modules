#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Act - no fields at all
$none = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field $null)

# Assert
Assert-That -Condition ($none -is [array]) -Message 'No fields still returns an array'
Assert-Equal -Expected 0 -Actual $none.Count -Message 'No fields returns no arguments'

#───────────────────────────────────────────────────────────────────────────────
# Act - two string fields, given out of order
$sorted = @(ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Field @{ title = 'T'; body = 'B' })

# Assert
Assert-Equal -Expected @('--raw-field', 'body=B', '--raw-field', 'title=T') -Actual $sorted `
    -Message 'Fields are emitted in sorted key order, each behind its own flag'

#───────────────────────────────────────────────────────────────────────────────
# Act - the values gh's -F typing understands
$typed = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ force = $true; draft = $false; parent = $null; count = 5 })

# Assert
Assert-Equal `
    -Expected @('--field', 'count=5', '--field', 'draft=false', '--field', 'force=true', '--field', 'parent=null') `
    -Actual $typed `
    -Message 'Bools are lower-cased, $null becomes null, and a number is written as-is'

#───────────────────────────────────────────────────────────────────────────────
# Act - an array value
$list = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ names = @('a', 'b') })

# Assert
Assert-Equal -Expected @('--field', 'names[]=a', '--field', 'names[]=b') -Actual $list `
    -Message 'An array value becomes one key[]=value pair per element'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array value
$emptyList = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ names = @() })

# Assert
Assert-Equal -Expected @('--field', 'names[]') -Actual $emptyList -Message 'An empty array value becomes a bare key[]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a nested hashtable, and an empty list inside it
$nested = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{
        protection = @{
            strict = $true
            checks = @('ci', 'lint')
            none   = @()
            inner  = @{ deep = 3 }
        }
    })

# Assert
Assert-Equal -Expected @(
    '--field', 'protection[checks][]=ci', '--field', 'protection[checks][]=lint',
    '--field', 'protection[inner][deep]=3', '--field', 'protection[none][]',
    '--field', 'protection[strict]=true'
) -Actual $nested `
    -Message 'A nested hashtable is one bracketed key per leaf, in sorted order, and an empty list stays a bare key[]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - dates, and a list that is not an array
$when = [DateTime]::new(2026, 10, 16, 12, 30, 0, [DateTimeKind]::Utc)
$offset = [DateTimeOffset]::new(2026, 10, 16, 12, 30, 0, [TimeSpan]::FromHours(-5))
$dates = @(ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Field @{ at = $when; offset = $offset })
$list = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ names = [System.Collections.Generic.List[string]]::new([string[]]@('a', 'b')) })

# Assert
Assert-Equal `
    -Expected @(
        '--raw-field', 'at=2026-10-16T12:30:00.0000000Z', '--raw-field', 'offset=2026-10-16T12:30:00.0000000-05:00'
    ) `
    -Actual $dates `
    -Message 'A date is written in ISO 8601, not in the culture''s own form'
Assert-Equal -Expected @('--field', 'names[]=a', '--field', 'names[]=b') -Actual $list `
    -Message 'A List is a list like an array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the same values under a culture that writes numbers and dates differently
$saved = [System.Threading.Thread]::CurrentThread.CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
try {
    $german = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ ratio = 1.5; at = $when })
}
finally {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $saved
}

# Assert
Assert-Equal -Expected @('--field', 'at=2026-10-16T12:30:00.0000000Z', '--field', 'ratio=1.5') -Actual $german `
    -Message 'The culture does not change what is sent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an ordered dictionary
$ordered = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field ([ordered]@{ b = 2; a = 1 }))

# Assert
Assert-Equal -Expected @('--field', 'a=1', '--field', 'b=2') -Actual $ordered `
    -Message 'An [ordered] dictionary is accepted, and still sorted'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - values gh's fields cannot express
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ items = @(@{ name = 'a' }) }
} -MessageLike "*Field 'items' holds a list of objects*-Body*" -Message 'A list of objects throws, pointing at -Body'
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ owner = [PSCustomObject]@{ login = 'octocat' } }
} -MessageLike "*Field 'owner' holds a PSCustomObject*-Body*" `
    -Message 'An object that is not a hashtable throws instead of being sent as its type name'
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ outer = @{ inner = @(, @(1, 2)) } }
} -MessageLike "*Field 'outer``[inner``]' holds a list of objects or lists*" `
    -Message 'A list inside a list throws, naming the nested key'

#───────────────────────────────────────────────────────────────────────────────
# Act - a switch, as a caller passes its own [switch] parameter on
$on = [switch]$true
$off = [switch]$false
$switches = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ draft = $on; other = $off; list = @($on) })

# Assert
Assert-Equal -Expected @('--field', 'draft=true', '--field', 'list[]=true', '--field', 'other=false') `
    -Actual $switches `
    -Message 'A switch is written like a bool, so gh sends a JSON boolean rather than the text True'

#───────────────────────────────────────────────────────────────────────────────
# Act - values that are not integers, which gh's -F sends as strings
$texts = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field ([ordered]@{ e = [DayOfWeek]::Monday; t = [TimeSpan]::FromHours(1) }))
$rawNull = @(ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Field @{ n = $null })

# Assert
Assert-Equal -Expected @('--field', 'e=Monday', '--field', 't=01:00:00') -Actual $texts `
    -Message 'An enum and a TimeSpan are written as their text'
Assert-Equal -Expected @('--raw-field', 'n=null') -Actual $rawNull `
    -Message 'A $null raw field is the text null, as the help says'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - shapes gh's field syntax would carry wrongly
$wrong = @(
    @{
        Fields = @{ outer = @{} }
        Like = "*Field 'outer' is an empty hashtable*-Body*"
        Message = 'An empty nested hashtable throws instead of the field disappearing'
    }
    @{
        Fields = @{ 'a=b' = 'c' }
        Like = "*Field key 'a=b' holds '=', '``[' or '``]'*-Body*"
        Message = 'A key holding = throws, since gh splits at the first ='
    }
    @{
        Fields = @{ 'a[b' = 'c' }
        Like = "*Field key 'a``[b' holds*"
        Message = 'A key holding [ throws, since gh reads it as nesting'
    }
    @{
        Fields = @{ outer = @{ 'x]' = 1 } }
        Like = "*Field key 'x``]' holds*"
        Message = 'and so does a nested key holding ]'
    }
)

# Assert
foreach ($case in $wrong) {
    Assert-Throws -ScriptBlock {
        ConvertTo-GitHubFieldArgument -Flag '--field' -Field $case.Fields
    } -MessageLike $case.Like -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act - fields named Keys and Count, at the top and nested
$shadowing = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field @{ keys = 'k1'; title = 't'; inner = @{ Count = 0 } })

# Assert
Assert-Equal -Expected @('--field', 'inner[Count]=0', '--field', 'keys=k1', '--field', 'title=t') -Actual $shadowing `
    -Message 'A field named keys or Count is one field among the others, never the list of them or their number'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a flag that is not one of gh's two field flags
Assert-Throws -ScriptBlock {
    ConvertTo-GitHubFieldArgument -Flag '--header' -Field @{ a = 1 }
} -MessageLike '*"--header" does not belong to the set*' `
    -Message 'Only --field and --raw-field are accepted as the flag'

#───────────────────────────────────────────────────────────────────────────────
# Act - the plural name -Field had before, which stays an alias
$byAlias = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Fields @{ title = 'x' })
$aliases = (Get-Command -Name ConvertTo-GitHubFieldArgument).Parameters['Field'].Aliases

# Assert
Assert-Equal -Expected @('--field', 'title=x') -Actual $byAlias -Message '-Fields still names the fields'
Assert-Equal -Expected @('Fields') -Actual @($aliases) -Message 'as the alias of -Field'

exit (Complete-TestRun)
