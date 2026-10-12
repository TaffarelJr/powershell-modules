#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one cache by id
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubCache -Id '1234' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '--repo', 'o/r', '--', '1234') -Actual $call.Arguments `
        -Message 'The repository goes through --repo and the cache comes last, after a --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every cache, scoped to a ref
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubCache -All -Ref 'refs/heads/main' -SucceedOnNoCaches
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '--all', '--ref=refs/heads/main', '--succeed-on-no-caches') `
        -Actual $call.Arguments `
        -Message '-All, -Ref, and -SucceedOnNoCaches become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - cache ids from the pipeline, as Get-GitHubCache returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ Id = '1'; Key = 'a' }, [PSCustomObject]@{ Id = '2'; Key = 'b' }) | Remove-GitHubCache
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped cache is deleted in its own call'
    Assert-Equal -Expected @('cache', 'delete', '--', '2') -Actual $calls[1].Arguments `
        -Message 'The Id property binds from the pipeline, not the text of the object'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - cache objects as Get-GitHubCache returns them, with a numeric Id
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ Id = [long]5000000001; Key = 'npm-abc'; SizeInBytes = 10 }
        [PSCustomObject]@{ Id = [long]5000000002; Key = 'npm-def'; SizeInBytes = 20 }
    ) | Remove-GitHubCache
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped cache object is deleted in its own call'
    Assert-Equal -Expected @('cache', 'delete', '--', '5000000002') -Actual $calls[1].Arguments `
        -Message 'A numeric Id is read as the cache id, not as the text of the object'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a cache key that looks like an option, and an object with no Id
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubCache -Id '--all'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '--', '--all') -Actual $call.Arguments `
        -Message 'A cache key is an operand whatever it starts with, so it cannot turn into --all'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Key = 'npm-abc' } | Remove-GitHubCache
    } -MessageLike 'A cache object needs an Id and a Key, as Get-GitHubCache gives, and this one lacks one:*' `
        -Message 'An object with no Id is refused'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called for it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing passed whole, and a hashtable
$fake = New-FakeGitHubCli
try {
    # Act
    $caches = @([PSCustomObject]@{ Id = [long]11; Key = 'a' }, [PSCustomObject]@{ Id = [long]12; Key = 'b' })
    Remove-GitHubCache -Id $caches
    Remove-GitHubCache -Id @{ Id = 5; Key = 'c' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 3 -Actual $calls.Count `
        -Message 'Each cache of a list given to -Id is deleted in its own call'
    Assert-Equal -Expected @('cache', 'delete', '--', '12') -Actual $calls[1].Arguments -Message 'by its Id'
    Assert-Equal -Expected @('cache', 'delete', '--', '5') -Actual $calls[2].Arguments `
        -Message 'and a hashtable is read by its Id key'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - caches listed from two repositories, as Get-GitHubCache
# -Repository returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ Id = [long]11; Key = 'a'; Repository = 'other/repo' }
        [PSCustomObject]@{ Id = [long]12; Key = 'b' }
    ) | Remove-GitHubCache
    $own = [PSCustomObject]@{ Id = [long]13; Key = 'c'; Repository = 'other/repo' }
    Remove-GitHubCache -Id $own -Repository 'github.com/OTHER/repo'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('cache', 'delete', '--repo', 'other/repo', '--', '11') -Actual $calls[0].Arguments `
        -Message 'A cache is deleted in the repository it came from'
    Assert-Equal -Expected @('cache', 'delete', '--', '12') -Actual $calls[1].Arguments `
        -Message 'and one of unknown origin in the current repository, not the previous cache''s'
    Assert-Equal -Expected @('cache', 'delete', '--repo', 'github.com/OTHER/repo', '--', '13') `
        -Actual $calls[2].Arguments `
        -Message 'A -Repository naming the cache''s own repository is used'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]14; Key = 'd'; Repository = 'other/repo' } | Remove-GitHubCache -Repository 'o/r'
    } -MessageLike 'Cache 14 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'A -Repository naming another repository than the cache''s throws'
    Assert-Equal -Expected 3 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that name no cache
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -Id '  '
    } -MessageLike "'  ' is not a cache: give its id or key, or a cache object." -Message 'A blank key is refused'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = $null; Key = 'a' } | Remove-GitHubCache
    } -MessageLike 'A cache object needs an Id and a Key*' -Message 'as is an object whose Id is $null'
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -Id $null
    } -MessageLike "*'Id'*null*" -Message 'and $null'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects of other kinds that carry an Id, as Get-GitHubWorkflow and
# a run's listing return them
$foreign = @(
    @{ Kind = 'workflow'; Object = [PSCustomObject]@{ Id = 4242; Path = '.github/workflows/ci.yml'; Name = 'CI' } }
    @{ Kind = 'run'; Object = [PSCustomObject]@{ Id = 4242; DatabaseId = 77; Status = 'completed' } }
)
$fake = New-FakeGitHubCli
try {
    foreach ($case in $foreign) {
        $object = $case.Object

        # Act / Assert
        Assert-Throws -ScriptBlock {
            $object | Remove-GitHubCache
        } -MessageLike 'A cache object needs an Id and a Key, as Get-GitHubCache gives, and this one lacks one:*' `
            -Message "A piped $($case.Kind) is refused, not read as a cache by its Id"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a blank ref, which would widen -All to every ref, and a
# repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -All -Ref ''
    } -MessageLike '-Ref was given but is blank, so it would filter nothing. Give a value, or leave -Ref off.' `
        -Message 'A blank -Ref is refused, not dropped to delete the caches of every ref'
    Assert-Throws -ScriptBlock {
        @([PSCustomObject]@{ Id = 1; Key = 'a'; Repository = 'a/b' }) | Remove-GitHubCache -All
    } -MessageLike '-All deletes every cache at once: pipe caches without -All, or give -All alone.' `
        -Message 'Caches piped in with -All are refused, not each answered with a whole deletion'
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -All -Repository $null
    } -MessageLike '-Repository was given, but it is $null - leave it out to use*' `
        -Message 'A -Repository given as $null is refused, not taken for the current directory''s'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot delete the cache
$fake = New-FakeGitHubCli -ErrorOutput @('X Could not find a cache matching 99') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -Id 99
    } -MessageLike '*Deleting cache 99 failed*Could not find a cache matching 99*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf for every cache with every other parameter, for caches
# by id and key, and with caches piped in
$fake = New-FakeGitHubCli
try {
    $caches = @(
        [PSCustomObject]@{ Id = [long]1; Key = 'a'; Repository = 'a/b' }
        [PSCustomObject]@{ Id = [long]2; Key = 'b' }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubCache -All -Ref 'refs/heads/main' -SucceedOnNoCaches -Repository 'o/r' -WhatIf
        Remove-GitHubCache -All -WhatIf
        Remove-GitHubCache -Id '1234', 'npm-abc' -Repository 'o/r' -WhatIf
        $caches | Remove-GitHubCache -WhatIf
    }

    # Assert
    $operation = 'What if: Performing the operation'
    $expected = @(
        "$operation ""Delete every cache for refs/heads/main"" on target ""o/r""."
        "$operation ""Delete every cache"" on target ""the current directory's repository""."
        "$operation ""Delete cache"" on target ""o/r cache 1234""."
        "$operation ""Delete every cache with this key, on every ref"" on target ""o/r cache key npm-abc""."
        "$operation ""Delete cache"" on target ""a/b cache 1""."
        "$operation ""Delete cache"" on target ""cache 2""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each cache, every one of a list, and what a key deletes'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories that carry a token
$fake = New-FakeGitHubCli
try {
    $url = 'https://user:SENTINEL@github.com/o/r'
    $cache = [PSCustomObject]@{ Id = [long]7; Key = 'k'; Repository = $url }

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubCache -All -Repository $url -WhatIf
        Remove-GitHubCache -Id 'npm-abc' -Repository ([PSCustomObject]@{ Url = $url }) -WhatIf
        $cache | Remove-GitHubCache -WhatIf
    }

    # Assert
    $operation = 'What if: Performing the operation'
    $expected = @(
        "$operation ""Delete every cache"" on target ""o/r""."
        "$operation ""Delete every cache with this key, on every ref"" on target ""o/r cache key npm-abc""."
        "$operation ""Delete cache"" on target ""o/r cache 7""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the repository as OWNER/REPO'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never shows the token'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Remove-GitHubCache -All -Ref '' -WhatIf
    } -MessageLike '-Ref was given but is blank, so it would filter nothing. Give a value, or leave -Ref off.' `
        -Message 'With -WhatIf, a blank -Ref is still refused'
    Assert-Throws -ScriptBlock {
        @([PSCustomObject]@{ Id = 1; Key = 'a'; Repository = 'a/b' }) | Remove-GitHubCache -All -WhatIf
    } -MessageLike '-All deletes every cache at once: pipe caches without -All, or give -All alone.' `
        -Message 'as are caches piped in with -All'

    # Act
    Remove-GitHubCache -All -Ref 'refs/heads/main' -SucceedOnNoCaches -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('cache', 'delete', '--all', '--ref=refs/heads/main', '--succeed-on-no-caches', '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$command = Get-Command -Name 'Remove-GitHubCache' -Module 'TaffarelJr.GitHub.Workflows'

# Assert
Assert-Equal -Expected 'Id' -Actual $command.DefaultParameterSet `
    -Message 'A call that names neither a cache nor -All is read as one that names a cache'
Assert-Equal -Expected @('All', 'Id') -Actual @($command.ParameterSets.Name | Sort-Object) `
    -Message 'whichever of the two sets it could have been'

exit (Complete-TestRun)
