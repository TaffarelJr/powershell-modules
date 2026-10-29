#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubCoreTestHelper.ps1')

$secret = 'SENTINEL_SECRET_123'
$token = 'ghp_' + ('A' * 36)

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, printing the secret on stdout and on stderr
$fake = New-FakeGitHubCli -Output @("saw $secret") -ErrorOutput @("gh: bad value $secret (HTTP 422)") -ExitCode 1
try {
    $arguments = @('config', 'set', '--', 'editor', $secret)

    # Act
    $unmasked = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity "Setting $secret" -Argument $arguments
    }
    $masked = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity "Setting $secret" -Argument $arguments -Mask $secret -Verbose
    }

    # Assert
    $hiddenMessage = "Setting *** failed: gh config set -- editor *** (exit 1)`nsaw ***`ngh: bad value *** (HTTP 422)"
    Assert-That -Condition $unmasked.Message.Contains($secret) `
        -Message 'Without -Mask the secret is in the failure message'
    Assert-Equal -Expected $hiddenMessage -Actual $masked.Message `
        -Message 'With -Mask it is hidden in the activity, in each argument, and in each line gh printed'
    Assert-Equal -Expected $masked.Message -Actual $masked.Target `
        -Message 'and so is the error''s target, which is that message'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $masked -Text $secret) `
        -Message 'and the error as PowerShell renders it, Get-Error, $Error[0], and every verbose line'
    Assert-Equal -Expected @('Setting ***: gh config set -- editor ***') -Actual $masked.Verbose `
        -Message 'The verbose line hides it too'

    # Act - the same call, tolerated
    $tolerated = Invoke-GitHubCommand -Activity "Setting $secret" -Argument $arguments -Mask $secret -Tolerant

    # Assert
    Assert-Equal -Expected "saw $secret`ngh: bad value $secret (HTTP 422)" -Actual $tolerated.Message `
        -Message 'A tolerated result keeps what gh printed exactly as it was printed, whatever -Mask names'

    #───────────────────────────────────────────────────────────────────────────
    # Act - values that hide nothing
    $nullMask = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity "Setting $secret" -Argument $arguments -Mask $null
    }
    $shortMask = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity "Setting $secret" -Argument $arguments -Mask @('', 'abc')
    }

    # Assert
    Assert-Equal -Expected $unmasked.Message -Actual $nullMask.Message `
        -Message 'A $null -Mask leaves the message as it was'
    Assert-Equal -Expected $unmasked.Message -Actual $shortMask.Message `
        -Message 'and so does one holding only an empty value and a value of fewer than four characters'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that prints a token on its own, and a secret that is not a token
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Forbidden $token and $secret") -ExitCode 1
try {
    # Act
    $both = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'x', $token, $secret) -Mask $secret
    }

    # Assert
    $bothMessage = "Reading failed: gh api x *** *** (exit 1)`ngh: Forbidden *** and ***"
    Assert-Equal -Expected $bothMessage -Actual $both.Message `
        -Message 'A token that stands alone and a masked value are both hidden in one message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a machine with no gh on its PATH
$savedPath = $env:PATH
$env:PATH = ''
try {
    # Act
    $missing = Get-GitHubCallOutcome {
        Invoke-GitHubCommand -Activity "Setting $secret" -Argument @('config', 'set') -Mask $secret -Tolerant
    }

    # Assert
    Assert-Equal -Expected 'Setting *** failed: gh was not found on PATH.' -Actual $missing.Message `
        -Message 'The activity is hidden when gh cannot be found'
}
finally {
    $env:PATH = $savedPath
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh api call that fails, given a secret as a raw field and as a header
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Validation Failed: $secret (HTTP 422)") -ExitCode 1
try {
    $arguments = @{
        Endpoint = 'repos/o/r/hooks'
        RawField = @{ password = $secret }
        Header   = @{ 'X-Api-Key' = $secret }
    }

    # Act
    $api = Get-GitHubCallOutcome { Invoke-GitHubApi @arguments -Verbose }

    # Assert
    $expectedCall = "gh api repos/o/r/hooks --raw-field password=*** --header 'X-Api-Key: ***'"
    $expectedMessage = "Calling repos/o/r/hooks failed: $expectedCall (exit 1)`ngh: Validation Failed: *** (HTTP 422)"
    Assert-Equal -Expected $expectedMessage -Actual $api.Message `
        -Message 'A raw field named password and a header are hidden in the failure message'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $api -Text $secret) `
        -Message 'and in the error''s target, its rendering, Get-Error, $Error[0], and every verbose line'
    $expectedVerbose = @(
        'Performing the operation "Call the GitHub API" on target "POST repos/o/r/hooks".'
        "Calling repos/o/r/hooks with gh's default method"
        "Calling repos/o/r/hooks: $expectedCall"
    )
    Assert-Equal -Expected $expectedVerbose -Actual $api.Verbose `
        -Message 'The verbose lines show *** in their place, and the ShouldProcess line shows neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - fields whose keys name a secret in each of the ways the pattern lists, nested and in a list, and
# fields that name none
$fake = New-FakeGitHubCli -ExitCode 1
try {
    $fields = @{
        config   = @{ secret = 'nested-value-1'; url = 'https://example.com/hook' }
        tokens   = @('list-value-1', 'list-value-2')
        Passwd   = 'mixed-case-value'
        private  = $true
        title    = 'plain-title-value'
        draft    = $true
        auth_key = $null
    }

    # Act
    $typed = Get-GitHubCallOutcome { Invoke-GitHubApi -Endpoint 'x' -Field $fields }
    $raw = Get-GitHubCallOutcome { Invoke-GitHubApi -Endpoint 'x' -RawField $fields }

    # Assert
    $expectedFields = @(
        '--field', 'auth_key=null'
        '--field', 'config[secret]=***'
        '--field', 'config[url]=https://example.com/hook'
        '--field', 'draft=true'
        '--field', 'Passwd=***'
        '--field', 'private=true'
        '--field', 'title=plain-title-value'
        '--field', 'tokens[]=***'
        '--field', 'tokens[]=***'
    ) -join ' '
    Assert-Equal -Expected "Calling x failed: gh api x $expectedFields (exit 1)" -Actual $typed.Message `
        -Message 'A value under a key that names a secret, nested or in a list, is hidden; every other value is shown'
    Assert-Equal -Expected "Calling x failed: gh api x $($expectedFields.Replace('--field', '--raw-field')) (exit 1)" `
        -Actual $raw.Message `
        -Message 'as it is for raw fields, where a bool or $null under such a key is not hidden either'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a value under a key that names no secret, which is the documented limit
$fake = New-FakeGitHubCli -ExitCode 1
try {
    # Act
    $title = Get-GitHubCallOutcome { Invoke-GitHubApi -Endpoint 'x' -RawField @{ title = $secret } -Body $secret }

    # Assert
    Assert-That -Condition ($title.Message -like "*--raw-field title=$secret --input - (exit 1)") `
        -Message 'A value under a key that names no secret is shown, and a -Body never is'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an endpoint with a GitHub token in its query string
$endpoint = "repos/o/r?access_token=$token"
$fake = New-FakeGitHubCli -ErrorOutput @("gh: Bad credentials for $token (HTTP 401)") -ExitCode 1
try {
    # Act
    $query = Get-GitHubCallOutcome { Invoke-GitHubApi -Endpoint $endpoint -Verbose }
    $paginate = Get-GitHubCallOutcome { Invoke-GitHubApi -Endpoint $endpoint -Method PUT -Paginate -Verbose }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $query -Text $token) `
        -Message 'A token in an endpoint is hidden in the verbose lines and in the failure message'
    Assert-Equal -Expected @("Calling repos/o/r?access_token=*** with gh's default method") `
        -Actual @($query.Verbose | Select-Object -First 1) -Message 'including the line that describes the call'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $paginate -Text $token) `
        -Message 'and in the error for -Paginate with a method that cannot page'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with text that is not JSON, and repeats a secret in it
$fake = New-FakeGitHubCli -Output @("moved to $token and $secret")
try {
    # Act
    $notJson = Get-GitHubCallOutcome {
        Invoke-GitHubApi -Endpoint $endpoint -RawField @{ password = $secret }
    }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $notJson -Text $secret) `
        -Message 'A secret echoed in a response that is not JSON is hidden in the error for it'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $notJson -Text $token) `
        -Message 'as is a token, and the endpoint it was asked of'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
