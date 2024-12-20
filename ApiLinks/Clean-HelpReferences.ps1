param(
    [Parameter(Mandatory=$true, Position=1)][string]$HelpPath,
    [Parameter(Mandatory=$true, Position=2)][string]$RefsPath
)

$refs = [System.Collections.Generic.SortedDictionary[String, object]]::new()
$existing = (Get-Content $RefsPath | ConvertFrom-Json -AsHashtable)
$suffix = $existing["#suffix"]
foreach ($pair in $existing.GetEnumerator()) {
    if ($pair.Name.StartsWith("#") -or $null -eq $pair.Value) {
        $refs[$pair.Name] = $pair.Value
        continue
    }

    $newValues = @()
    foreach ($value in $pair.Value) {
        if ($value.StartsWith("#") -or $value.StartsWith("http")) {
            $newValues += $value
        } else {
            $path = Join-Path $HelpPath ($value + $suffix)
            if (Test-Path $path) {
                $newValues += $value
            } else {
                Write-Warning "Missing $($pair.Name): $path"
            }
        }
    }

    if ($newValues.Count -gt 1) {
        $refs[$pair.Name] = $newValues
    } elseif ($newValues.Count -eq 1) {
        $refs[$pair.Name] = $newValues[0]
    }
}

$refs | Sort-Object Name | ConvertTo-Json | Set-Content $RefsPath
