#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path $tree | Out-Null
    [File]::WriteAllText((Join-Path $tree 'PlaceholderNotes.txt'), "Placeholder`r`n", [UTF8Encoding]::new($false))
    $before = Get-FileTextTreeState -Path $tree
    $message = "Cannot rename 'Placeholder' to 'Bad/Name': not a legal file name"

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        #───────────────────────────────────────────────────────────────────────
        # Act - a failing call whose caller asked for errors to be hidden
        $output = @()
        $caught = $null
        try {
            $output = @(Rename-Token -Path $tree -From 'Placeholder' -To 'Bad/Name' -ErrorAction $preference)
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) `
            -Message "Under -ErrorAction $preference a failing call still changes nothing"
        Assert-Equal -Expected 0 -Actual $output.Count -Message 'and returns nothing'
        Assert-Equal -Expected 'RuntimeException,Rename-Token' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $caught = $null
    try {
        Rename-Token -Path $tree -From 'Placeholder' -To 'Bad/Name'
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Rename-Token' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A failing call raises a terminating error whose ID is the failure kind and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected $message -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $tree -From 'Placeholder' -To 'Bad/Name' -ErrorAction Stop } `
        -MessageLike '*not a legal file name*' `
        -Message 'Under -ErrorAction Stop a failing call still throws'
    Assert-Equal -Expected $before -Actual (Get-FileTextTreeState -Path $tree) `
        -Message 'and changes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a token that is refused only at the end of the run, when an item cannot be renamed
    $taken = Join-Path $sandbox 'taken'
    New-Item -ItemType Directory -Path $taken | Out-Null
    [File]::WriteAllText((Join-Path $taken 'Placeholder.txt'), 'x')
    [File]::WriteAllText((Join-Path $taken 'Real.txt'), 'y')
    $takenBefore = Get-FileTextTreeState -Path $taken

    # Act
    $caught = $null
    try {
        Rename-Token -Path $taken -From 'Placeholder' -To 'Real' -ErrorAction SilentlyContinue
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Rename-Token' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A rename that cannot be done is raised at the end of the run, whatever the caller hid'
    Assert-That -Condition ($caught.Exception.Message -like "Could not rename 'Placeholder' -> 'Real' in 1 item(s):*") `
        -Message 'naming how many items it could not do'
    Assert-Equal -Expected $takenBefore -Actual (Get-FileTextTreeState -Path $taken) `
        -Message 'and the item that could not be renamed is left as it was'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
