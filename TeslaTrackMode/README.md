# Tesla track mode telemetry

Two scripts that operate on the telemetry that a Tesla Model 3 Performance records to the USB drive
while in track mode.

`Fix-TeslaTelemetry.ps1` converts the elapsed time field in the telemetry from a lap timer to a
total session time. This is the correct format expected by applications like
[RaceRender](https://racerender.com/) which create a video overlay based on the telemetry. It can
also fix negative brake pressure values which I've occasionally seen in my telemetry.

`Get-TeslaLap.ps1` just pulls all the lap times out of the file, so you can quickly find the fastest
lap.
