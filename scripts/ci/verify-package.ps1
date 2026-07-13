[CmdletBinding()]
param(
	[Parameter(Mandatory)][ValidateSet("shared", "game-static")][string]$Variant,
	[Parameter(Mandatory)][string]$Directory
)

$ErrorActionPreference = "Stop"
$hdll = Join-Path $Directory "hlmedia.hdll"
if (-not (Test-Path $hdll)) { throw "Missing hlmedia.hdll." }
$dependencies = (dumpbin /DEPENDENTS $hdll 2>&1) -join "`n"
if ($LASTEXITCODE) { throw "dumpbin failed for hlmedia.hdll." }
Write-Output $dependencies
$ffmpegPattern = "(?im)^\s*(avcodec|avformat|avutil|swresample|swscale)-[^\s]+\.dll\s*$"
$packagedFFmpeg = Get-ChildItem $Directory -File | Where-Object Name -Match "^(avcodec|avformat|avutil|swresample|swscale)-.*\.dll$"

if ($Variant -eq "game-static") {
	if ($dependencies -match $ffmpegPattern) { throw "Static package depends on FFmpeg DLLs." }
	if ($packagedFFmpeg) { throw "Static package contains FFmpeg DLLs." }
	foreach ($name in "FFMPEG-COMMIT.txt", "FFMPEG-CONFIGURE.txt", "COPYING.LGPLv2.1", "LICENSE.md") {
		if (-not (Test-Path (Join-Path $Directory $name))) { throw "Missing $name." }
	}
	$configuration = Get-Content (Join-Path $Directory "FFMPEG-CONFIGURE.txt") -Raw
	if ($configuration -notmatch "--enable-hwaccel=h264_(d3d11va|dxva2|d3d12va)") {
		throw "Static FFmpeg metadata reports no Windows H.264 hardware accelerator."
	}
} else {
	if ($dependencies -notmatch $ffmpegPattern) { throw "Shared package has no FFmpeg DLL dependencies." }
	$dependencyNames = [regex]::Matches($dependencies, $ffmpegPattern) | ForEach-Object { $_.Value.Trim() }
	foreach ($name in $dependencyNames) {
		if (-not (Test-Path (Join-Path $Directory $name))) { throw "Missing dependent FFmpeg runtime $name." }
	}
}

if (-not (Test-Path (Join-Path $Directory "BUILD_INFO.txt"))) { throw "Missing BUILD_INFO.txt." }
Write-Output "Package verification passed for $Variant."
