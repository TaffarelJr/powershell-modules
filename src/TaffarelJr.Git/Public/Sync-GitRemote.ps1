using namespace System.Collections.Generic

function Sync-GitRemote {
    <#
    .SYNOPSIS
        Fetches from a remote.
    .PARAMETER Name
        The remote to fetch. Defaults to 'origin'. Ignored when -All is
        set.
    .PARAMETER Refspec
        A specific branch or refspec to fetch, instead of the remote's
        usual set.
    .PARAMETER Prune
        Removes local remote-tracking refs whose branch no longer exists
        on the remote.
    .PARAMETER Tags
        Also fetches every tag.
    .PARAMETER All
        Fetches every configured remote instead of just -Name.
    .PARAMETER RepoPath
        The repo to fetch into. Omit it to use the current working
        directory.
    #>
    param(
        [string]$Name = 'origin',

        [string]$Refspec,

        [switch]$Prune,

        [switch]$Tags,

        [switch]$All,

        [string]$RepoPath
    )

    $arguments = [List[string]]::new()
    $arguments.Add('fetch')
    if ($All) {
        $arguments.Add('--all')
    }

    if ($Prune) {
        $arguments.Add('--prune')
    }

    if ($Tags) {
        $arguments.Add('--tags')
    }

    if (-not $All) {
        $arguments.Add($Name)
        if ($Refspec) {
            $arguments.Add($Refspec)
        }
    }

    Invoke-GitCommand -Activity 'Fetching' -Arguments $arguments -RepoPath $RepoPath | Out-Null
}
