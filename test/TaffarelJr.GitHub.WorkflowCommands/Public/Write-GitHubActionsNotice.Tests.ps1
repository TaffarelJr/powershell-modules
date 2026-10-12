#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act - message only, no properties
$lines = @(Get-WorkflowCommand { Write-GitHubActionsNotice 'deprecated input ignored' })

# Assert
Assert-Equal -Expected @('::notice::deprecated input ignored') -Actual $lines `
    -Message 'With no properties, no space or property list appears before the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act
$located = @(Get-WorkflowCommand { Write-GitHubActionsNotice -Message 'missing trailing newline' -File 'main.ps1' -Line 7 })

# Assert
Assert-Equal -Expected @('::notice file=main.ps1,line=7::missing trailing newline') -Actual $located `
    -Message 'File and line are rendered ahead of the data segment'

#───────────────────────────────────────────────────────────────────────────────
# Act
$piped = @(Get-WorkflowCommand { 'one', 'two' | Write-GitHubActionsNotice })

# Assert
Assert-Equal -Expected @('::notice::one', '::notice::two') -Actual $piped `
    -Message 'Each piped message is written as an annotation of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act - an object carrying the message and where it points
$fromObject = @(Get-WorkflowCommand {
        [PSCustomObject]@{
            Message = 'unused'
            File = 'a.ps1'
            Line = 3
            EndLine = 3
            Column = 5
            EndColumn = 9
            Title = 'Lint'
        },
        [PSCustomObject]@{ Message = 'bare' } |
            Write-GitHubActionsNotice
    })

# Assert
Assert-Equal `
    -Expected @('::notice file=a.ps1,line=3,endLine=3,col=5,endColumn=9,title=Lint::unused', '::notice::bare') `
    -Actual $fromObject `
    -Message 'A piped object''s Message, File, Line, EndLine, Column, EndColumn, and Title properties are taken by name, each object''s own'

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromColumn = @(Get-WorkflowCommand { [PSCustomObject]@{ Message = 'm'; Line = 1; Col = 2 } | Write-GitHubActionsNotice })

# Assert
Assert-Equal -Expected @('::notice line=1,col=2::m') -Actual $fromColumn `
    -Message 'as is a Col property, the start column''s other name'

#───────────────────────────────────────────────────────────────────────────────
# Act - Select-String's records from piped text, which name no file
$matched = @(Get-WorkflowCommand { 'abc', 'TODO one', 'TODO two' | Select-String -Pattern 'TODO' | Write-GitHubActionsNotice })

# Assert
Assert-Equal -Expected @('::notice line=2::TODO one', '::notice line=3::TODO two') -Actual $matched `
    -Message 'A Select-String match annotates its line number with the matched text, one annotation per match'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files to search, one whose matching line is a number
$sandbox = New-WorkflowCommandsSandbox
$searched = Join-Path $sandbox 'a.ps1'
$numbered = Join-Path $sandbox 'b.txt'
[IO.File]::WriteAllText($searched, "x`nTODO one`n42`nTODO two`n")
[IO.File]::WriteAllText($numbered, "7`n")

# Act
$fromFiles = @(Get-WorkflowCommand {
        Select-String -LiteralPath $searched -Pattern 'TODO' | Write-GitHubActionsNotice
        Select-String -LiteralPath $numbered -Pattern '^\d+$' | Write-GitHubActionsNotice
    })
Remove-Item -LiteralPath $sandbox -Recurse -Force

# Assert
$searchedFile = $searched.Replace(':', '%3A')
$numberedFile = $numbered.Replace(':', '%3A')
Assert-Equal -Expected @(
    "::notice file=$searchedFile,line=2::TODO one"
    "::notice file=$searchedFile,line=4::TODO two"
    "::notice file=$numberedFile,line=1::7"
) -Actual $fromFiles `
    -Message 'A match in a file annotates that file at the match''s line, and matched digits are never taken for a line'

#───────────────────────────────────────────────────────────────────────────────
# Act - Message properties that are not text
$nonText = @(Get-WorkflowCommand {
        [PSCustomObject]@{ Message = 42; Line = 3 },
        [PSCustomObject]@{ Message = [datetime]'2024-01-02' } |
            Write-GitHubActionsNotice
    })

# Assert
Assert-Equal -Expected @('::notice line=3::42', '::notice::01/02/2024 00:00:00') -Actual $nonText `
    -Message 'A piped object''s Message property is taken as its text, whatever its type'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { [PSCustomObject]@{ File = 'f.ps1'; Line = 3 } | Write-GitHubActionsNotice } `
    -MessageLike 'A piped object needs a Message property, or give the text: PSCustomObject.' `
    -Message 'A piped object with no Message property throws, rather than annotating its own text'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { [PSCustomObject]@{ Message = $null; Line = 3 } | Write-GitHubActionsNotice } `
    -MessageLike 'A piped object''s Message property is $null: give it the text.' `
    -Message 'as does one whose Message property is $null'

#───────────────────────────────────────────────────────────────────────────────
# Act
$wholeNumbers = @(Get-WorkflowCommand {
        Write-GitHubActionsNotice -Message 'a' -Line 5.0
        Write-GitHubActionsNotice -Message 'b' -Line 6L
        [PSCustomObject]@{ Message = 'c'; Line = 7.0 } | Write-GitHubActionsNotice
        [PSCustomObject]@{
            Message = 'd'
            Line = 2.5
        }, [PSCustomObject]@{ Message = 'e'; Line = '8' } | Write-GitHubActionsNotice
    })

# Assert
Assert-Equal `
    -Expected @('::notice line=5::a', '::notice line=6::b', '::notice line=7::c', '::notice::d', '::notice::e') `
    -Actual $wholeNumbers `
        -Message 'A whole number of any numeric type is a position, given or piped; a piped fraction or text is not'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -Line 2.5 } `
    -MessageLike "-Line is '2.5', which is not a whole number: give one from 1 to 2147483647, or leave it out." `
    -Message 'On the command line, a fraction is refused'

#───────────────────────────────────────────────────────────────────────────────
# Act - piped properties holding nothing usable
$unusable = @(Get-WorkflowCommand {
        [PSCustomObject]@{ Message = 'zero'; Line = 0 },
        [PSCustomObject]@{ Message = 'untitled'; Title = '' },
        [PSCustomObject]@{ Message = 'nowhere'; File = $null },
        [PSCustomObject]@{ Message = 'blank'; File = ' '; Title = ' ' } |
            Write-GitHubActionsNotice
    })

# Assert
Assert-Equal -Expected @('::notice::zero', '::notice::untitled', '::notice::nowhere', '::notice::blank') `
    -Actual $unusable `
    -Message 'A piped 0, empty, blank, or $null property is taken as not given'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -Line 'abc' } `
    -MessageLike "-Line is 'abc', which is not a whole number: give one from 1 to 2147483647, or leave it out." `
    -Message 'On the command line, a line that is not a number is refused'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -File '' } `
    -MessageLike '-File is blank: give the file''s path, or leave it out.' `
    -Message 'as is an empty file'

#───────────────────────────────────────────────────────────────────────────────
# Act
$full = @(Get-WorkflowCommand {
        Write-GitHubActionsNotice -Message 'bad: thing' -File 'a,b.ps1' -Line 3 -EndLine 3 -Column 2 -EndColumn 9 `
            -Title 'T:1'
    })

# Assert
Assert-Equal -Expected @('::notice file=a%2Cb.ps1,line=3,endLine=3,col=2,endColumn=9,title=T%3A1::bad: thing') `
    -Actual $full `
    -Message 'Every property is rendered in order, with : and , escaped in a value but not in the message'

#───────────────────────────────────────────────────────────────────────────────
# Act
$alias = @(Get-WorkflowCommand { Write-GitHubActionsNotice -Message 'x' -Line 1 -Col 4 })

# Assert
Assert-Equal -Expected @('::notice line=1,col=4::x') -Actual $alias -Message '-Col still names the start column'

#───────────────────────────────────────────────────────────────────────────────
# Act - a message and a title needing escaping
$escaped = @(Get-WorkflowCommand { Write-GitHubActionsNotice -Message "multi`nline :: msg %" -Title "T:: x,y`r`nz" })

# Assert
Assert-Equal -Expected @('::notice title=T%3A%3A x%2Cy%0D%0Az::multi%0Aline :: msg %25') -Actual $escaped `
    -Message 'The message is escaped as command data and the title as a property'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -File 'a' -Line 0 } `
    -MessageLike "-Line is 0, but it must be from 1 to 2147483647: give one in that range, or leave it out." `
    -Message 'A line below 1 is refused, not dropped without a word'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -Line 1 -Column 0 } `
    -MessageLike "-Column is 0, but it must be from 1 to 2147483647: give one in that range, or leave it out." `
    -Message 'A column below 1 is refused'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -Column 2 } `
    -MessageLike '-Column was given without -Line, so the runner would drop the columns: give -Line too.' `
    -Message 'A position the runner would drop is refused'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -File ' ' } `
    -MessageLike '-File is blank: give the file''s path, or leave it out.' `
    -Message 'A blank file is refused'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Write-GitHubActionsNotice -Message 'x' -Title ' ' } `
    -MessageLike '-Title is blank: give a title, or leave it out.' `
    -Message 'A blank title is refused'
#───────────────────────────────────────────────────────────────────────────────
# Act - positions given on the command line as whole-number text
$fromText = @(Get-WorkflowCommand {
        Write-GitHubActionsNotice -Message 'a' -Line '42'
        Write-GitHubActionsNotice -Message 'b' -Line '9' -EndLine 12
        $null = 'n=7' -match 'n=(?<n>\d+)'
        Write-GitHubActionsNotice -Message 'c' -Line $Matches.n
        Write-GitHubActionsNotice -Message 'd' -Line 3 -Column '4'
        Write-GitHubActionsNotice -Message 'e' -Line '05'
    })

# Assert
Assert-Equal -Expected @(
    '::notice line=42::a'
    '::notice line=9,endLine=12::b'
    '::notice line=7::c'
    '::notice line=3,col=4::d'
    '::notice line=5::e'
) -Actual $fromText -Message 'Whole-number text given on the command line is the position it names'

#───────────────────────────────────────────────────────────────────────────────
# Act - a message given on the command line that is not text
$nonText = @(Get-WorkflowCommand {
        Write-GitHubActionsNotice -Message 42
        Write-GitHubActionsNotice -Message @('two', 'words')
    })

# Assert
Assert-Equal -Expected @('::notice::42', '::notice::two words') -Actual $nonText `
    -Message 'A message given on the command line is taken as its text, whatever its type'

exit (Complete-TestRun)
