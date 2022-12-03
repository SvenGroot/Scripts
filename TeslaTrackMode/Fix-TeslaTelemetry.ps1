param(
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="Path", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]] $Path,
    [Parameter(Mandatory=$true, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName=$true)]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath,
    [Parameter(Position=1)][string]$OutputPath,
    [Parameter()][switch]$FixBrakePressure
)
begin {
    if ($OutputPath -and -not (Test-Path $OutputPath -PathType Container)) {
        throw "'$OutputPath' is not a directory."
    }
}
process {
    if ($Path) {
        $inputs = Get-Item -Path $Path
    } else {
        $inputs = Get-Item -LiteralPath $LiteralPath
    }
    
    foreach ($file in $inputs)
    {
        $output = $OutputPath
        if (-not $output) {
            $output = $file.DirectoryName
        }

        $output = Join-Path $output "$($file.BaseName).fixed.csv"
        $prevLapTime = 0
        $currentLap = 0
        Write-Verbose "Processing $($file.Name)..."
        Import-Csv $file | ForEach-Object {
            $lap = $_.Lap
            $lapTime = $_.'Elapsed Time (ms)'
            if ($lap -ne $currentLap) {
                $prevLapTime = $totalTime
                $currentLap = $lap
            }

            $totalTime = $prevLapTime + $lapTime
            $_.'Elapsed Time (ms)' = $totalTime
            # Preserve the original lap time in a new field.
            $_ | Add-Member -MemberType NoteProperty -Name "Lap Time (ms)" -Value $lapTime

            if ($FixBrakePressure -and $_.'Brake Pressure (bar)' -lt 0) {
                $_.'Brake Pressure (bar)' = 0
            }

            $_
        } | Export-Csv $output
    }
}