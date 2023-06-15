param(
    # Specifies a path to one or more locations. Wildcards are permitted.
    [Parameter(Mandatory=$true,
               Position=0,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
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
    [Parameter(Mandatory=$true, Position=1)][string]$HelpPath
)
Begin {
    $helpFiles = [System.Collections.Generic.HashSet[String]]::new()
    Get-ChildItem $HelpPath | ForEach-Object {
        $helpFiles.Add($_.BaseName) | Out-Null
    }
}
Process {
    if ($Path) {
        $items = Get-Item -Path $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    foreach ($item in $items) {
        $refs = [System.Collections.Generic.SortedDictionary[String, object]]::new()
        $existing = (Get-Content $item | ConvertFrom-Json -AsHashtable)
        foreach ($pair in $existing.GetEnumerator()) {
            if ($pair.Name.StartsWith("#")) {
                $refs.Add($pair.Name, $pair.Value)
                continue
            }

            $targets = $pair.Value | ForEach-Object {
                if ($null -ne $_) {
                    if (-not ($_.Contains("://") -or $_.StartsWith("#")) -and -not ($helpFiles.Contains($_))) {
                        Write-Warning "Removing target $_ from $($pair.Name)"
                    } else {
                        $_
                    }
                }
            }

            if ($targets) {
                $refs.Add($pair.Name, $targets)
            }
        }

        $refs | ConvertTo-Json | Set-Content $item
    }
}
