param(
	[string]$Destination = ".",
	[string]$Source
)

$defaultSource = Join-Path (Split-Path -Parent $PSScriptRoot) "dist/hlmedia-windows-shared-x64"
$source = if ($Source) { Resolve-Path -LiteralPath $Source } elseif (Test-Path -LiteralPath $defaultSource) { $defaultSource } else { $PSScriptRoot }
$target = Resolve-Path -LiteralPath $Destination

Get-ChildItem -LiteralPath $source -File |
	Where-Object { $_.Extension -eq ".dll" -or $_.Extension -eq ".hdll" } |
	Copy-Item -Destination $target -Force
