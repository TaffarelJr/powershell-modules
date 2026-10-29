#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force `
    -PassThru

function Find-Sample {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'Read by the script block or child process the test hands it to, by scope.')]
    param(
        [string[]]$Owner,
        [object[]]$Repository,
        [string]$Author,
        [string[]]$Label,
        [switch]$NoLabel,
        [switch]$Locked,
        [switch]$Draft,
        [switch]$Archived,
        [ValidateSet('open', 'closed')]
        [string]$State,
        [ValidateSet('public', 'private')]
        [string[]]$Visibility,
        [ValidateSet('false', 'true', 'only')]
        [string]$IncludeForks,
        [string]$Order,
        [string]$SearchType,
        [string]$Checks,
        [string]$Review,
        [switch]$IncludePullRequests,
        [switch]$Merged,
        [switch]$Merge,
        [switch]$NoMilestone,
        [switch]$NoAssignee,
        [switch]$NoProject,
        [object]$Created,
        [ValidateSet('created', 'updated')]
        [string]$Sort,
        [ValidateSet('title', 'body')]
        [string[]]$Match,
        [int]$Limit
    )
}

function Get-SearchArgument {
    param($Bound, $Query, [hashtable]$Extra = @{})

    $search = @{
        Subcommand  = 'issues'
        JsonFields  = 'number,title'
        Command     = Get-Command Find-Sample
        Bound       = $Bound
        Flag        = [ordered]@{
            Owner        = '--owner'
            Repository   = '--repo'
            Author       = '--author'
            Label        = '--label'
            NoLabel      = '--no-label'
            Locked       = '--locked'
            Draft        = '--draft'
            Archived     = '--archived'
            State        = '--state'
            Visibility   = '--visibility'
            IncludeForks = '--include-forks'
            Created      = '--created'
            Match        = '--match'
            Sort         = '--sort'
            Limit        = '--limit'
            Order        = '--order'
            SearchType   = '--search-type'
            Checks       = '--checks'
            Review       = '--review'
            IncludePullRequests = '--include-prs'
            Merged       = '--merged'
            Merge        = '--merge'
            NoMilestone  = '--no-milestone'
            NoAssignee   = '--no-assignee'
            NoProject    = '--no-project'
        }
        Date        = @('Created')
        PresentOnly = @('NoLabel')
        Query       = $Query
    }
    $search += $Extra

    return @(& $module {
            param($s)
            ConvertTo-GitHubSearchArgument @s
        } $search)
}

$head = @('search', 'issues', '--json', 'number,title')
$env:GH_HOST = $null

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a string, a list, and a number, passed in an order other than the map's
$bound = @{ Limit = 5; Label = @('bug', 'docs'); Author = 'me' }

# Act
$arguments = Get-SearchArgument -Bound $bound -Query $null

# Assert
Assert-Equal -Expected ($head + @('--author', 'me', '--label', 'bug', '--label', 'docs', '--limit', '5')) `
    -Actual $arguments `
    -Message 'Flags come out in the map''s order, a list as one flag per value, and a number as text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - switches given and withheld
$bound = @{ Author = 'me'; NoLabel = [switch]$true; Draft = [switch]$false; Archived = [switch]$false }

# Act
$arguments = Get-SearchArgument -Bound $bound -Query $null

# Assert
Assert-Equal -Expected ($head + @('--author', 'me', '--no-label', '--draft=false', '--archived=false')) `
    -Actual $arguments `
    -Message 'A switch is the bare flag, and a switch passed as false is that flag set to false in one argument, as a separate false would be read as a keyword'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values of ValidateSet parameters in another case, and a free-text one
$bound = @{ Sort = 'Created'; Match = @('TITLE', 'Body'); Author = 'MonaLisa' }

# Act
$arguments = Get-SearchArgument -Bound $bound -Query $null

# Assert
Assert-Equal -Expected ($head + @('--author', 'MonaLisa', '--match', 'title', '--match', 'body', '--sort', 'created')) `
    -Actual $arguments `
    -Message 'A ValidateSet value goes to gh in lower case, as GitHub ignores a sort it does not recognize; free text keeps its case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a parameter the map does not name
$bound = @{ Author = 'me'; Query = 'ignored'; Verbose = [switch]$true }

# Act
$arguments = Get-SearchArgument -Bound $bound -Query @('crash')

# Assert
Assert-Equal -Expected ($head + @('--author', 'me', '--', 'crash')) -Actual $arguments `
    -Message 'A parameter the map does not name is not sent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories in every form gh's search can be given, one of them an object
$repository = [pscustomobject]@{ Url = 'https://github.com/cli/cli'; NameWithOwner = 'cli/cli' }
$bound = @{ Repository = @($repository, 'https://github.com/o/r.git', 'github.com/a/b', 'c/d'); Author = 'me' }

# Act
$arguments = Get-SearchArgument -Bound $bound -Query $null

# Assert
Assert-Equal `
    -Expected ($head + @('--repo', 'cli/cli', '--repo', 'o/r', '--repo', 'a/b', '--repo', 'c/d', '--author', 'me')) `
    -Actual $arguments `
    -Message 'Each --repo value is cut down to OWNER/REPO, an object read by its Url, as gh sends it to GitHub word for word'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - repositories gh's search cannot find
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @('cli') } -Query $null
} -MessageLike "'cli' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL." `
    -Message 'A bare name throws rather than search for a repo: qualifier GitHub cannot match'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @('a/b', 'ghe.example.com/o/r') } -Query $null
} -MessageLike "'ghe.example.com/o/r' is on ghe.example.com, but GH_HOST is not set, so it is compared with github.com: set GH_HOST to ghe.example.com to search there." `
    -Message 'A repository on another host throws, pointing at GH_HOST'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @([pscustomobject]@{ Name = 'r' }) } -Query $null
} -MessageLike 'A repository object needs a repository''s web URL*' `
    -Message 'An object with nothing to read throws Core''s message'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - filters that were passed but say nothing
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Owner = [string[]]@(); Label = @('bug') } -Query $null
} -MessageLike '-Owner was given but is empty*widen, as far as all of GitHub*leave -Owner off.' `
    -Message 'An empty list throws rather than be left out, which would widen the search'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = ' ' } -Query @('x')
} -MessageLike '-Author was given but is blank, so it would filter nothing*Give a value, or leave -Author off.' `
    -Message 'A blank value throws'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = $null } -Query @('x')
} -MessageLike '-Author was given, but it is $null, so it would filter nothing*Give a value, or leave -Author off.' `
    -Message 'A $null value throws, saying so'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = $null } -Query @('x')
} -MessageLike '-Repository was given, but it is $null*leave -Repository off.' `
    -Message 'and so does a $null repository list'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Label = @('bug', '') } -Query $null
} -MessageLike '-Label holds a blank value, which would filter nothing. Give only real values.' `
    -Message 'A blank value in a list throws'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @(' ') } -Query $null
} -MessageLike '-Repository was given but is blank, so it would filter nothing*Give a value, or leave -Repository off.' `
    -Message 'while a single blank value gets the blank-filter sentence, not the list one'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @('a/b', $null) } -Query $null
} -MessageLike '-Repository holds a blank value*' -Message 'and so does a $null repository in a list'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a list value holding a comma
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Label = @('good first issue', 'a,b') } -Query $null
} -MessageLike "-Label value 'a,b' holds a comma*split it into two filters. Give each value on its own (-Label 'a', 'b')*-Query*'label:`"a,b`"'." `
    -Message 'A comma in a list value throws, since gh would search for two labels, and says how to give either meaning'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Repository = @('a/b,c/d') } -Query $null
} -MessageLike "-Repository value 'a/b,c/d' holds a comma*Give each value on its own (-Repository 'a', 'b')*" `
    -Message 'and a repository list written as one text value is told to give each on its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - midnight dates of every kind, and a date as text
$rows = @(
    @{
        Value = [datetime]::new(2026, 1, 2, 0, 0, 0, [DateTimeKind]::Local)
        Message = 'A Local [datetime] at midnight is the day it shows, with no shift to UTC'
    }
    @{ Value = [datetime]::new(2026, 1, 2, 0, 0, 0, [DateTimeKind]::Utc); Message = 'and so is a Utc one' }
    @{ Value = [datetime]::new(2026, 1, 2); Message = 'and an Unspecified one' }
    @{
        Value = [datetimeoffset]::new(2026, 1, 2, 0, 0, 0, [timespan]::FromHours(5))
        Message = 'and a [datetimeoffset] at midnight, read by its own clock'
    }
    @{ Value = [datetimeoffset]::new(2026, 1, 2, 0, 0, 0, [timespan]::FromHours(-8)); Message = 'whatever its offset' }
)

# Act / Assert
foreach ($row in $rows) {
    Assert-Equal -Expected ($head + @('--created', '2026-01-02')) `
        -Actual (Get-SearchArgument -Bound @{ Created = $row.Value } -Query $null) `
        -Message $row.Message
}

Assert-Equal -Expected ($head + @('--created', '2026-01-01..2026-01-31')) `
    -Actual (Get-SearchArgument -Bound @{ Created = '2026-01-01..2026-01-31' } -Query $null) `
    -Message 'A date as text is sent as given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - dates with a time of day, which GitHub would match to the exact second
$rows = @(
    @{
        Value = [datetime]::new(2026, 3, 4, 10, 30, 15, [DateTimeKind]::Utc)
        Message = 'A Utc [datetime] with a time of day throws'
    }
    @{ Value = [datetime]::new(2026, 3, 4, 10, 30, 15, [DateTimeKind]::Local); Message = 'and so does a Local one' }
    @{ Value = [datetime]::new(2026, 3, 4, 0, 0, 1); Message = 'and an Unspecified one a second past midnight' }
    @{
        Value = [datetimeoffset]::new(2026, 3, 4, 10, 30, 15, [timespan]::Zero)
        Message = 'and a [datetimeoffset] with a time'
    }
)

# Act / Assert
foreach ($row in $rows) {
    Assert-Throws -ScriptBlock {
        Get-SearchArgument -Bound @{ Created = $row.Value } -Query $null
    } -MessageLike "-Created got a date with a time of day, which GitHub matches to the exact second. Give a date (.Date), or text such as '>=2026-10-11T09:33:17Z'." `
        -Message $row.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a date that is neither a date nor text
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Created = @('2026-01-01', '2026-02-01') } -Query $null
} -MessageLike "-Created takes one date or date range, as a ``[datetime``], a ``[datetimeoffset``], or text*'>2026-01-01', not a Object``[``]." `
    -Message 'A list of dates throws, naming what it got'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Created = ' ' } -Query $null
} -MessageLike '-Created was given but is blank*' -Message 'A blank date throws like any blank filter'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Created = $null } -Query $null
} -MessageLike '-Created was given, but it is $null*' -Message 'and a $null one says so'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a present-only switch passed as false
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ NoLabel = [switch]$false; Author = 'me' } -Query $null
} -MessageLike '-NoLabel:$false filters nothing: gh ignores --no-label=false*Leave -NoLabel off instead.' `
    -Message 'A switch gh only reads when true throws when passed as false'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a switch whose false form is a keyword
$extra = @{ FalseKeyword = @{ Locked = 'is:unlocked' } }

# Act
$false1 = Get-SearchArgument -Bound @{ Locked = [switch]$false } -Query @('crash') -Extra $extra
$true1 = Get-SearchArgument -Bound @{ Author = 'me'; Locked = [switch]$true } -Query $null -Extra $extra

# Assert
Assert-Equal -Expected ($head + @('--', 'crash', 'is:unlocked')) -Actual $false1 `
    -Message 'Passed as false, it becomes its keyword after the caller''s own'
Assert-Equal -Expected ($head + @('--author', 'me', '--locked')) -Actual $true1 `
    -Message 'Passed as true, it is still the bare flag'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$bound = @{ Author = 'me' }

# Act - a query of several keywords, one of them an exclusion
$arguments = Get-SearchArgument -Bound $bound -Query @('crash on start', '-label:wontfix')

# Assert
Assert-Equal -Expected ($head + @('--author', 'me', '--', 'crash on start', '-label:wontfix')) -Actual $arguments `
    -Message 'The keywords come last, one argument each, after a -- so a leading dash is not an option'

#───────────────────────────────────────────────────────────────────────────────
# Act - a query alone, with no filter
$arguments = Get-SearchArgument -Bound @{} -Query @('crash')

# Assert
Assert-Equal -Expected ($head + @('--', 'crash')) -Actual $arguments -Message 'A query needs no filter'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - blank keywords, and a query given with none
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = 'me' } -Query @('crash', ' ')
} -MessageLike '-Query holds a blank keyword, which searches for nothing. Give only real keywords.' `
    -Message 'A whitespace keyword throws rather than be sent as a phrase of nothing'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = 'me' } -Query @('')
} -MessageLike '-Query holds a blank keyword*' -Message 'and so does an empty one'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = 'me'; Query = $null } -Query $null
} -MessageLike '-Query was given but holds no keyword, which searches for nothing. Give a keyword, or leave -Query off.' `
    -Message 'A query given as $null throws rather than be dropped'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Author = 'me'; Query = [string[]]@() } -Query ([string[]]@())
} -MessageLike '-Query was given but holds no keyword*' -Message 'and so does one given as an empty list'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option that only shapes the results or picks a state, each alone
$message = 'Give a query or at least one filter: with neither, the search would cover all of GitHub. Options that only shape the results or pick a state do not narrow it: -Limit, -Sort, -Order, -Match, -SearchType, -State, -Checks, -Review, -Visibility, -IncludeForks, -IncludePullRequests, and the switches -Archived, -Merged, -Draft, -Locked, -Merge, -NoLabel, -NoMilestone, -NoAssignee, and -NoProject.'
$rows = [ordered]@{
    Limit               = 5
    Sort                = 'created'
    Order               = 'asc'
    Match               = @('title')
    SearchType          = 'semantic'
    State               = 'open'
    Checks              = 'failure'
    Review              = 'approved'
    Visibility          = @('public')
    IncludeForks        = 'true'
    IncludePullRequests = [switch]$true
    Archived            = [switch]$true
    Merged              = [switch]$true
    Draft               = [switch]$true
    Locked              = [switch]$true
    Merge               = [switch]$true
    NoLabel             = [switch]$true
    NoMilestone         = [switch]$true
    NoAssignee          = [switch]$true
    NoProject           = [switch]$true
}

# Act / Assert
foreach ($name in $rows.PSBase.Keys) {
    Assert-Throws -ScriptBlock {
        Get-SearchArgument -Bound @{ $name = $rows[$name] } -Query $null
    } -MessageLike ([WildcardPattern]::Escape($message)) `
        -Message "-$name alone does not narrow the search, so gh is not called"
    Assert-Equal -Expected '--author' `
        -Actual (Get-SearchArgument -Bound @{ $name = $rows[$name]; Author = 'me' } -Query $null)[4] `
        -Message "and with a filter that narrows it, -$name goes to gh with it"
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - nothing at all, and switches passed as false
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{} -Query $null
} -MessageLike 'Give a query or at least one filter*' `
    -Message 'No query and no filter throws, where gh would search all of GitHub'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Draft = [switch]$false } -Query $null
} -MessageLike 'Give a query or at least one filter*' `
    -Message 'and so does a switch passed as false, which asks for nearly everything'
Assert-Throws -ScriptBlock {
    Get-SearchArgument -Bound @{ Locked = [switch]$false } -Query $null -Extra $extra
} -MessageLike 'Give a query or at least one filter*' `
    -Message 'A switch whose false form is a keyword does not count as a query either'

exit (Complete-TestRun)
