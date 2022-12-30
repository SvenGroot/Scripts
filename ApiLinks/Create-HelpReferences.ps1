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
    [Parameter(Mandatory=$true, Position=1)][string]$HelpPath,
    [Parameter(Mandatory=$true, Position=2)][string]$RefsPath,
    [Parameter(Mandatory=$false)][Switch]$Cpp,
    [Parameter(Mandatory=$false)][string]$CppNamespace
)
begin {
    $ErrorActionPreference = "Stop"
    . "$PSScriptRoot/common.ps1"
    $refs = [System.Collections.Generic.SortedDictionary[String, object]]::new()
    if (Test-Path $RefsPath) {
        $existing = (Get-Content $RefsPath | ConvertFrom-Json -AsHashtable)
        foreach ($pair in $existing.GetEnumerator()) {
            $refs[$pair.Name] = $pair.Value
        }
    } else {
        if ($Cpp) {
            $refs["#apiPrefix"] = "https://en.cppreference.com/w/cpp/"
        } else {
            $refs["#apiPrefix"] = "https://learn.microsoft.com/dotnet/api/"
        }

        $refs["#prefix"] = "https://example.com/"
        $refs["#suffix"] = ".htm"
    }

    if ($Cpp) {
        $tags = [xml](Get-Content $HelpPath)
    }
}
process {
    if ($Path) {
        $items = Get-Item -Path $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    $items | Get-Content | ForEach-Object {
        # Find `text` blocks, only if not preceeded by [ (that's already a link).
        $regex = '(?<!\[)`(?<ref>[A-Z][a-zA-Z0-9.,<>() ]*?)`'
        if ($Cpp) {
            $regex = '(?<!\[)`(?<ref>[a-z]([a-zA-Z0-9:_<>()]|(, ?))*?)`'
        }

        $m = $_ | Select-String $regex -AllMatches -CaseSensitive
        if ($m) {
            $m.Matches | ForEach-Object {
                Write-Host $_.Groups["ref"]
                if ($Cpp) {
                    Resolve-CppReference $tags $_.Groups["ref"] $CppNamespace $refs
                } else {
                    Resolve-Reference $HelpPath $_.Groups["ref"] $refs
                }
            }
        }
    }
}
end {
    $refs | Sort-Object Name | ConvertTo-Json | Set-Content $RefsPath
}