param(
	[string]$Destination = "."
)

$nativeSource = Join-Path (Split-Path -Parent $PSScriptRoot) "native-libs"
$source = if (Test-Path -LiteralPath $nativeSource) { $nativeSource } else { $PSScriptRoot }
$target = Resolve-Path -LiteralPath $Destination

Get-ChildItem -LiteralPath $source -File |
	Where-Object { $_.Extension -eq ".dll" -or $_.Extension -eq ".hdll" } |
	Copy-Item -Destination $target -Force
