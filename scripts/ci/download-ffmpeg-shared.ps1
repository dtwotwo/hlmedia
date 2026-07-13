[CmdletBinding()]
param(
	[string]$OutputDirectory = "out/deps/ffmpeg-shared",
	[string]$Url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-lgpl-shared.zip"
)

$ErrorActionPreference = "Stop"
$archive = "$OutputDirectory.zip"
Remove-Item -Recurse -Force $OutputDirectory -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
curl.exe --fail --location $Url --output $archive
if ($LASTEXITCODE) { throw "FFmpeg download failed." }
Expand-Archive $archive -DestinationPath $OutputDirectory -Force
$root = Get-ChildItem $OutputDirectory -Directory -Recurse | Where-Object {
	(Test-Path (Join-Path $_.FullName "include/libavcodec/avcodec.h")) -and
	(Test-Path (Join-Path $_.FullName "lib/avcodec.lib")) -and
	(Test-Path (Join-Path $_.FullName "bin"))
} | Select-Object -First 1
if (-not $root) {
	throw "Could not locate the extracted LGPL shared FFmpeg SDK."
}

if ($env:GITHUB_ENV) { "FFMPEG_SHARED_ROOT=$($root.FullName)" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append }
$env:FFMPEG_SHARED_ROOT = $root.FullName
Write-Output $root.FullName
