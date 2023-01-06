param(
    # Specifies a path to one or more locations.
    [Parameter(Mandatory=$true,
               Position=0,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $Path,
    # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
    # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
    # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
    # characters as escape sequences.
    [Parameter(Mandatory=$true,
               ParameterSetName="LiteralPath",
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Literal path to one or more locations.")]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $LiteralPath,
    [Parameter(Mandatory=$true, Position=1)][string]$RefsPath,
    [Parameter(Mandatory=$false)][Switch]$Cpp
)
begin {
    $ErrorActionPreference = "Stop"
    . "$PSScriptRoot/common.ps1"
    $refs = (Get-Content $RefsPath | ConvertFrom-Json -AsHashtable)
}
process {
    if ($Path) {
        $items = Get-Item -Path $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    foreach ($item in $items)
    {
        $labels = [System.Collections.Generic.SortedDictionary[String, object]]::new()
        $content = Get-Content $item | ForEach-Object {
            Write-Host $_
            # Find `text` blocks, only if not preceded by [ (that's already a link).
            $regex = '(?<!\[)`(?<ref>[A-Z][a-zA-Z0-9.,<>() ]*?)`'
            if ($Cpp) {
                $regex = '(?<!\[)`(?<ref>[A-Za-z]([a-zA-Z0-9:_<>()]|(, ?))*?)`'
            }

            $_ -creplace $regex,{
                $text = $_.Value
                $link = Resolve-Link $_.Groups["ref"] $refs $labels
                if ($link) {
                    if ($link -eq $text) {
                        "[$text][]"
                    } else {
                        "[$text][$link]"
                    }
                } else {
                    $text
                }
            }
        }

        $content | Set-Content $item

        "" | Out-File $item -Append

        $prefix = $refs["#prefix"]
        $suffix = $refs["#suffix"]
        $apiPrefix = $refs["#apiPrefix"]
        $labels.GetEnumerator() | ForEach-Object {
            if ($_.Value.Contains("://")) {
                "[$($_.Key)]: $($_.Value)"
            } elseif ($_.Value.StartsWith("#")) {
                "[$($_.Key)]: $apiPrefix$($_.Value.Substring(1))"
            } else {
                "[$($_.Key)]: $prefix$($_.Value)$suffix"
            }
        } | Out-File $item -Append
    }
}
