#Requires -Version 7.6

<#
.SYNOPSIS
    The text of a module's wiki pages.

.DESCRIPTION
    Dot-source this file after ReleaseName.ps1. It defines functions and runs
    nothing.

    Help is plain text. Each of its paragraphs is joined onto one line and its
    Markdown characters are escaped, so a path such as <path> is not read as a
    tag and a dollar sign is not read as math. A paragraph with an indented
    line or a list is kept as it is, in a code block. Authored Markdown, such
    as a README, only has its wrapped paragraphs joined.

    A wiki shows each page's name as its title, so a page never repeats it in
    a heading of its own. Every link to another page is the bare page name,
    which GitHub resolves from the wiki's root and from any page.

    -ModuleName is a module's short name, such as Tally; -ListedModule is a
    list of objects with a Name, a Version and a Description.
#>
using namespace System.Collections.Generic

function Get-LongestBacktickRunLength {
    <#
    .SYNOPSIS
        Returns the length of the longest run of backticks in the text.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $longest = 0
    foreach ($run in [regex]::Matches($Text, '`+')) {
        $longest = [Math]::Max($longest, $run.Length)
    }

    return $longest
}

function ConvertTo-CodeSpan {
    <#
    .SYNOPSIS
        Returns the text as an inline code span.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $mark = '`' * ((Get-LongestBacktickRunLength -Text $Text) + 1)
    $edge = $Text.StartsWith('`', [StringComparison]::Ordinal) -or
    $Text.EndsWith('`', [StringComparison]::Ordinal)
    $pad = if ($edge) { ' ' } else { '' }
    return "$mark$pad$Text$pad$mark"
}

function ConvertTo-CodeBlock {
    <#
    .SYNOPSIS
        Returns the text in a fenced code block, with a fence longer than any
        run of backticks in the text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [string]$Language = ''
    )

    $fence = '`' * [Math]::Max(3, (Get-LongestBacktickRunLength -Text $Text) + 1)
    return "$fence$Language`n$Text`n$fence"
}

function ConvertTo-EscapedText {
    <#
    .SYNOPSIS
        Returns the text with every character Markdown reads as syntax
        escaped, so it shows as written.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    return [regex]::Replace($Text, '[\\`*_\[\]<>|$#~&]', '\$0')
}

function Format-PageLink {
    <#
    .SYNOPSIS
        Returns a link to a wiki page by its bare name, with a label that is
        the name unless one is given.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Target,

        [string]$Label
    )

    if (-not $Label) {
        $Label = $Target
    }

    $destination = $Target.Replace(' ', '%20').Replace('(', '%28').Replace(')', '%29')
    $destination = $destination.Replace('<', '%3C').Replace('>', '%3E')
    return "[$(ConvertTo-EscapedText -Text $Label)]($destination)"
}

function Test-VerbatimLine {
    <#
    .SYNOPSIS
        Says whether a line of help must be kept as written: it is indented,
        starts a list, or is a rule.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )

    return ($Line -match '^\s') -or
    ($Line -match '^([-*+]|\d+[.)])\s') -or
    ($Line -match '^[-=_*]{3,}\s*$')
}

function ConvertTo-HelpMarkdown {
    <#
    .SYNOPSIS
        Returns plain help text as Markdown paragraphs.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $normal = ($Text -replace "`r`n", "`n").Trim()
    if (-not $normal) {
        return ''
    }

    $blocks = [List[string]]::new()
    foreach ($paragraph in [regex]::Split($normal, "\n[ \t]*\n+")) {
        $lines = $paragraph -split "`n"
        $verbatim = @($lines | Where-Object { Test-VerbatimLine -Line $_ })
        if ($verbatim.Count -gt 0) {
            $blocks.Add((ConvertTo-CodeBlock -Text $paragraph))
        }
        else {
            $joined = ($lines | ForEach-Object { $_.Trim() }) -join ' '
            $blocks.Add((ConvertTo-EscapedText -Text $joined))
        }
    }

    return $blocks -join "`n`n"
}

function Test-ProseLine {
    <#
    .SYNOPSIS
        Says whether a line of Markdown is plain prose that may be joined to
        the prose lines around it.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )

    if (-not $Line.Trim() -or $Line -match '^\s' -or $Line -match '(  |\\)$') {
        return $false
    }

    $block = '^(#|>|\||<|[-*+]\s|\d+[.)]\s|\[[^\]]+\]:\s|[-=_*]{3,}\s*$)'
    return $Line -notmatch $block
}

function Join-WrappedProse {
    <#
    .SYNOPSIS
        Returns Markdown with each wrapped paragraph joined onto one line.
        Code blocks, lists, tables, headings and indented lines are left
        exactly as written.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Markdown
    )

    $output = [List[string]]::new()
    $run = [List[string]]::new()
    $flush = {
        if ($run.Count -gt 0) {
            $output.Add(($run -join ' '))
            $run.Clear()
        }
    }

    $fence = $null
    foreach ($line in ($Markdown -replace "`r`n", "`n") -split "`n") {
        if ($fence) {
            $output.Add($line)
            $close = [regex]::Match($line, '^\s{0,3}(`{3,}|~{3,})\s*$')
            if ($close.Success -and $close.Groups[1].Value[0] -eq $fence[0] -and
                $close.Groups[1].Length -ge $fence.Length) {
                $fence = $null
            }

            continue
        }

        $open = [regex]::Match($line, '^\s{0,3}(`{3,}|~{3,})')
        if ($open.Success) {
            & $flush
            $output.Add($line)
            $fence = $open.Groups[1].Value
        }
        elseif (Test-ProseLine -Line $line) {
            $run.Add($line.Trim())
        }
        else {
            & $flush
            $output.Add($line)
        }
    }

    & $flush
    return $output -join "`n"
}

function Get-GeneratedNote {
    <#
    .SYNOPSIS
        Returns the comment every generated page starts with.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '<!-- Generated from the module when a release is published. Do not edit. -->'
}

function Get-UnindentedText {
    <#
    .SYNOPSIS
        Returns text with the indentation that every line after the first has
        in common taken off, as a value written across lines in source is.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $lines = $Text -split "`n"
    $rest = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() })
    if ($rest.Count -eq 0) {
        return $Text
    }

    $indents = @($rest | ForEach-Object { $_.Length - $_.TrimStart().Length })
    $common = ($indents | Measure-Object -Minimum).Minimum
    $kept = @($lines | Select-Object -Skip 1 | ForEach-Object {
            if ($_.Length -ge $common) { $_.Substring($common) } else { $_.TrimStart() }
        })
    return (@($lines[0]) + $kept) -join "`n"
}

function Format-Parameter {
    <#
    .SYNOPSIS
        Returns the section of a command page that describes one parameter.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Parameter
    )

    $blocks = [List[string]]::new()
    $blocks.Add("### -$($Parameter.Name)")
    $description = ConvertTo-HelpMarkdown -Text $Parameter.Description
    if ($description) {
        $blocks.Add($description)
    }

    $facts = [List[string]]::new()
    if ($Parameter.Type) {
        $facts.Add('- **Type:** ' + (ConvertTo-CodeSpan -Text $Parameter.Type))
    }

    $facts.Add('- **Required:** ' + $(if ($Parameter.Required) { 'yes' } else { 'no' }))
    $facts.Add('- **Position:** ' + $Parameter.Position)
    $default = ''
    if ($Parameter.DefaultValue -and $Parameter.Type -cne 'SwitchParameter') {
        $default = ($Parameter.DefaultValue -replace "`r`n", "`n").Trim()
    }

    $multiLine = $default.Contains("`n")
    if ($default -and -not $multiLine) {
        $facts.Add('- **Default value:** ' + (ConvertTo-CodeSpan -Text $default))
    }

    if ($Parameter.PipelineInput -like 'true*') {
        $accepts = $Parameter.PipelineInput -replace '^true', 'yes'
        $facts.Add('- **Accepts pipeline input:** ' + $accepts)
    }

    $blocks.Add(($facts -join "`n"))
    if ($multiLine) {
        $blocks.Add('Default value:')
        $code = Get-UnindentedText -Text $default
        $blocks.Add((ConvertTo-CodeBlock -Text $code -Language 'powershell'))
    }

    return $blocks -join "`n`n"
}

function Format-RelatedLink {
    <#
    .SYNOPSIS
        Returns the list item for one related link of a command: a web
        address, a command of the module, or plain text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Link,

        [Parameter(Mandatory)]
        [string[]]$Command
    )

    $text = [string]$Link.Text
    $uri = [string]$Link.Uri
    if ($uri) {
        $label = if ($text) { $text } else { $uri }
        return '- ' + (Format-PageLink -Target $uri -Label $label)
    }

    if ($text -in $Command) {
        return '- ' + (Format-PageLink -Target $text)
    }

    if ($text) {
        return '- ' + (ConvertTo-EscapedText -Text $text)
    }
}

function Format-CommandPage {
    <#
    .SYNOPSIS
        Returns the page of one command: its synopsis, syntax, description,
        examples, parameters, inputs, outputs and related links.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Help,

        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string[]]$Command
    )

    $commonUri = 'https://learn.microsoft.com/en-us/powershell/module/' +
    'microsoft.powershell.core/about/about_commonparameters'
    $fullName = Resolve-ModuleName -Name $ModuleName
    $moduleLink = Format-PageLink -Target $ModuleName -Label $fullName
    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add("$(ConvertTo-CodeSpan -Text $Help.Name) is a command in the $moduleLink module.")
    $blocks.Add((ConvertTo-HelpMarkdown -Text $Help.Synopsis))
    $blocks.Add('## Syntax')
    $blocks.Add((ConvertTo-CodeBlock -Text (@($Help.Syntax) -join "`n") -Language 'powershell'))
    $blocks.Add('## Description')
    $blocks.Add((ConvertTo-HelpMarkdown -Text $Help.Description))

    $blocks.Add('## Examples')
    $index = 0
    foreach ($example in @($Help.Examples)) {
        $index++
        $blocks.Add("### Example $index")
        $blocks.Add((ConvertTo-CodeBlock -Text $example.Code -Language 'powershell'))
        $remarks = ConvertTo-HelpMarkdown -Text $example.Remarks
        if ($remarks) {
            $blocks.Add($remarks)
        }
    }

    $blocks.Add('## Parameters')
    foreach ($parameter in @($Help.Parameters)) {
        $blocks.Add((Format-Parameter -Parameter $parameter))
    }

    $blocks.Add("This command supports the [common parameters]($commonUri).")
    foreach ($section in 'Inputs', 'Outputs') {
        $entries = @($Help.$section | Where-Object { $_ })
        if ($entries.Count -gt 0) {
            $blocks.Add("## $section")
            $entries | ForEach-Object { $blocks.Add((ConvertTo-HelpMarkdown -Text $_)) }
        }
    }

    $links = @($Help.Links | ForEach-Object { Format-RelatedLink -Link $_ -Command $Command })
    if ($links.Count -gt 0) {
        $blocks.Add('## Related links')
        $blocks.Add(($links -join "`n"))
    }

    return $blocks -join "`n`n"
}

function Format-ModuleOverview {
    <#
    .SYNOPSIS
        Returns a module's overview page: its README, then a table of its
        commands with their synopses.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$Readme,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Help
    )

    $body = (($Readme -replace "`r`n", "`n") -replace '\A\s*# [^\n]*\n', '').Trim()
    $rows = [List[string]]::new()
    $rows.Add('| Command | Description |')
    $rows.Add('| :--- | :--- |')
    foreach ($command in $Help) {
        $synopsis = (ConvertTo-HelpMarkdown -Text $command.Synopsis) -replace '\s*\n+\s*', ' '
        $rows.Add("| $(Format-PageLink -Target $command.Name) | $synopsis |")
    }

    $changelog = Format-PageLink -Target "$ModuleName-Changelog" -Label 'changelog'
    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add((Join-WrappedProse -Markdown $body))
    $blocks.Add('## Commands')
    $blocks.Add(($rows -join "`n"))
    $blocks.Add("See the $changelog.")
    return $blocks -join "`n`n"
}

function Format-ChangelogPage {
    <#
    .SYNOPSIS
        Returns a module's changelog page: a note that it is generated, and
        every release from the changelog without its own header.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Changelog
    )

    $start = $Changelog.IndexOf('## [', [StringComparison]::Ordinal)
    $releases = $Changelog.Substring($start).Trim()
    $keep = Format-PageLink -Target 'https://keepachangelog.com/en/1.1.0/' -Label 'Keep a Changelog'
    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add("All notable changes to this module are documented here, in the format of $keep.")
    $blocks.Add($releases)
    return $blocks -join "`n`n"
}

function Format-ModuleSidebar {
    <#
    .SYNOPSIS
        Returns the sidebar of a module's pages: a link back to every module,
        the module's changelog, and its commands.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string[]]$Command
    )

    $items = $Command | ForEach-Object { '- ' + (Format-PageLink -Target $_) }
    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add((Format-PageLink -Target 'Home' -Label 'All modules'))
    $blocks.Add('**' + (Format-PageLink -Target $ModuleName) + '**')
    $blocks.Add('- ' + (Format-PageLink -Target "$ModuleName-Changelog" -Label 'Changelog'))
    $blocks.Add('**Commands**')
    $blocks.Add(($items -join "`n"))
    return $blocks -join "`n`n"
}

function Format-RootSidebar {
    <#
    .SYNOPSIS
        Returns the sidebar of the wiki's own pages: Home and every module.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$ListedModule
    )

    $items = $ListedModule | ForEach-Object { '- ' + (Format-PageLink -Target $_.Name) }
    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add('**' + (Format-PageLink -Target 'Home') + '**')
    $blocks.Add('**Modules**')
    $blocks.Add(($items -join "`n"))
    return $blocks -join "`n`n"
}

function Get-HomeIntroduction {
    <#
    .SYNOPSIS
        Returns the paragraph that opens the wiki's home page.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $address = 'https://github.com/TaffarelJr/powershell-modules'
    $collection = Format-PageLink -Target $address -Label 'powershell-modules'
    return "Reference for the modules in the $collection collection, " +
    'with a page for every command. Pick a module to see its commands.'
}

function Format-Home {
    <#
    .SYNOPSIS
        Returns the wiki's home page: an introduction, then each module with
        its description, its version and a link to its changelog.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$ListedModule
    )

    $blocks = [List[string]]::new()
    $blocks.Add((Get-GeneratedNote))
    $blocks.Add((Get-HomeIntroduction))
    foreach ($entry in $ListedModule) {
        $fullName = Resolve-ModuleName -Name $entry.Name
        $gallery = "https://www.powershellgallery.com/packages/$fullName/$($entry.Version)"
        $version = Format-PageLink -Target $gallery -Label $entry.Version
        $changelog = Format-PageLink -Target "$($entry.Name)-Changelog" -Label 'Changelog'
        $blocks.Add('## ' + (Format-PageLink -Target $entry.Name))
        $blocks.Add((ConvertTo-EscapedText -Text $entry.Description))
        $blocks.Add("Version $version - $changelog")
    }

    return $blocks -join "`n`n"
}
