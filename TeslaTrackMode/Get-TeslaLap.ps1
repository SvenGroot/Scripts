param(
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="Path", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]] $Path,
    [Parameter(Mandatory=$true, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName=$true)]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath
)
process {
    if ($Path) {
        $inputs = Get-Item -Path $Path
    } else {
        $inputs = Get-Item -LiteralPath $LiteralPath
    }
    
    foreach ($file in $inputs)
    {
        $prevTime = 0
        $currentLap = 0
        Write-Verbose "Processing $($file.Name)..."
        Import-Csv $file | ForEach-Object {
            $lap = $_.Lap
            if ($lap -ne $currentLap) {
                [PSCustomObject]@{
                    Lap = $currentLap
                    Time = [timespan]::FromMilliseconds($prevTime)
                    File = $file.Name
                }

                $currentLap = $lap
            }

            $prevTime = $_.'Lap Time (ms)'
            if (-not $prevTime) {
                $prevTime = $_.'Elapsed Time (ms)'
            }
        } | Sort-Object Time
    }
}