#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# The real gh, talking to a loopback server, is the judge of which repository a
# reference names: what Split-GitHubRepositoryReference reads (and so what
# Assert-GitHubSameRepository compares) must be what gh acts on.
if (-not (Test-GitHubCliInstalled)) {
    exit (Skip-TestRun -Reason 'gh is not installed here')
}

$forms = [System.Collections.Generic.List[string]]::new()
foreach ($text in 'o/r', 'o/r.git', 'o/r/', 'o/r.git/', 'o/my.git-tools', 'O/R') {
    $forms.Add($text)
}

foreach ($server in 'github.localhost', 'GitHub.LocalHost', 'github.com', 'www.github.com', 'ghe.example.com', 'ghe.example.com:8443') {
    foreach ($suffix in '', '.git', '/') {
        $forms.Add("$server/o/r$suffix")
        $forms.Add("https://$server/o/r$suffix")
    }

    foreach ($form in 'http://{0}/o/r.git', 'ssh://git@{0}/o/r.git', 'git://{0}/o/r.git', 'git+ssh://git@{0}/o/r.git',
        'git+https://{0}/o/r.git', 'git@{0}:o/r.git') {
        $forms.Add(($form -f $server))
    }
}

foreach ($text in 'GIT@github.localhost:o/r', 'HTTPS://github.localhost/o/r.git', 'https://user:pw@github.localhost/o/r.git',
    'ssh://git@github.localhost:22/o/r.git', 'git@github.localhost:8443/o/r', 'git@github.localhost/o/r',
    'https://api.github.localhost/repos/o/r', 'https://github.localhost:443/o/r', 'git+https://user@github.localhost/o/r',
    'https://user:p@ss@github.localhost/o/r.git', 'ssh://git@x@github.localhost/o/r.git', 'git@x@github.localhost:o/r',
    'https://github.localhost?x=a@b/o/r', 'https://user:p?ss@github.localhost/o/r.git') {
    $forms.Add($text)
}

# Which host, owner, and repository gh asked for; 'refused' when it asked for none.
$readByGh = {
    param([string]$Reference)
    $before = @(Get-FakeGitHubRequest -Server $server).Count
    $arguments = @('issue', 'list', '--repo', $Reference, '--limit', '1', '--json', 'number')
    $result = Invoke-GitHubCommand -Activity 'Asking' -Argument $arguments -Tolerant
    foreach ($request in @(Get-FakeGitHubRequest -Server $server | Select-Object -Skip $before)) {
        if ($request.Method -eq 'CONNECT') {
            return 'github.com'
        }

        if ($request.Text -match '"owner":"(?<owner>[^"]*)","repo":"(?<repo>[^"]*)"') {
            return "github.localhost|$($Matches['owner'])|$($Matches['repo'])"
        }
    }

    if ("$($result.Message)" -cmatch '(?:Get|Post) "https?://(?:api\.)?(?<host>[^/"]+)/') {
        return $Matches['host']
    }

    return 'refused'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$server = Start-FakeGitHubServer -Route @{ '/graphql' = @{ Body = '{"data":{"repository":null}}' } }
try {
    # Act
    $disagreements = foreach ($form in $forms) {
        try {
            $reference = ConvertTo-GitHubRepositoryReference -Repository $form
        }
        catch {
            continue
        }

        $gh = & $readByGh $reference
        $parts = & $module { param($Text) Split-GitHubRepositoryReference -Reference $Text } $form
        $split = 'nothing'
        if ($null -ne $parts) {
            $hostName = if ($parts.Host) { $parts.Host.ToLowerInvariant() } else { 'github.localhost' }
            $split = "$hostName|$($parts.Owner)|$($parts.Name)"
        }

        $agree = switch -Wildcard ($gh) {
            'refused' { $true }
            'github.localhost|*' { $split -eq $gh }
            default { $split -like "$gh|*" }
        }

        if ($split -eq 'nothing' -and $gh -ne 'refused') {
            $agree = $false
        }

        if (-not $agree) {
            "$form -> converter [$reference], gh [$gh], split [$split]"
        }
    }

    # Assert
    Assert-Equal -Expected @() -Actual @($disagreements) `
        -Message "Over $($forms.Count) references, Split reads what gh reads, and reads nothing only where gh reads no repository"
}
finally {
    Stop-FakeGitHubServer -Server $server
}

exit (Complete-TestRun)
