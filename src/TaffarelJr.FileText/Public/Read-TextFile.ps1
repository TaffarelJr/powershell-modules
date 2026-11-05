using namespace System.Text

function Read-TextFile {
    <#
    .SYNOPSIS
        Reads a text file's content, encoding, and line ending,
        so a rewrite can preserve all three.
    .DESCRIPTION
        The file is decoded strictly. Text that is not valid in its encoding -
        a Windows-1252 file read as UTF-8, say, or a UTF-8 one read with
        -Encoding ASCII - throws rather than coming back with replacement
        characters, which a rewrite would then make permanent.

        A file that cannot be read - missing, a folder, not on the file
        system, or not valid in its encoding - is a terminating error, and in
        a pipeline it stops the pipeline.
    .PARAMETER Path
        The file to read. A relative path is relative to PowerShell's current
        location. Path strings can be piped in, and so can files from
        Get-ChildItem (by their FullName or PSPath) and Resolve-Path output
        (by its Path).
    .PARAMETER Encoding
        What to read a file with no byte order mark as, instead of UTF-8. A
        byte order mark still decides. Takes a System.Text.Encoding object,
        such as [Text.Encoding]::GetEncoding(1252) - not a name like 'utf8'
        as Get-Content does. It comes back as the file's Encoding, without a
        mark of its own, so passing that on to Write-TextFile writes the file
        back the way it was read.
    .INPUTS
        System.String. The path of a file; or any object with a FullName,
        PSPath, or Path property, such as the files Get-ChildItem returns.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. One per file, with
        Content, Encoding, and LineEnding.
    .EXAMPLE
        $file = Read-TextFile -Path ./README.md

        Reads README.md; $file.Content is its text, $file.Encoding the encoding
        it is written in, and $file.LineEnding its line ending.
    .EXAMPLE
        $file = Read-TextFile -Path ./legacy.txt `
            -Encoding ([Text.Encoding]::GetEncoding(1252))
        $text = $file.Content.Replace('old', 'new')
        Write-TextFile -Path ./legacy.txt -Content $text `
            -Encoding $file.Encoding

        Edits a Windows-1252 file, which has no byte order mark to read, and
        writes it back as Windows-1252.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Write-TextFile
    .LINK
        Get-FileEncoding
    .LINK
        Get-LineEnding
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string]$Path,

        [Encoding]$Encoding
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $full = Resolve-TextFilePath -Path $Path -MustExist
            $decoded = Read-DecodedText -Path $full -Encoding $Encoding
            if ($decoded.Problem) {
                throw $decoded.Problem
            }

            return [PSCustomObject]@{
                Content    = $decoded.Content
                Encoding   = $decoded.Encoding
                LineEnding = Get-LineEnding -Content $decoded.Content
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
