[CmdletBinding()]
param(
	[Parameter(Mandatory)][ValidateSet("shared", "game-static")][string]$Variant,
	[Parameter(Mandatory)][string]$Preset,
	[Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ffmpegRoot = if ($Variant -eq "shared") { $env:FFMPEG_SHARED_ROOT } else { $env:FFMPEG_GAME_STATIC_ROOT }
if (-not $ffmpegRoot) {
	throw "The FFmpeg SDK root environment variable is not set for $Variant."
}

Remove-Item -Recurse -Force $OutputDirectory -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
cmake --install "out/build/$Preset" --config Release --prefix $OutputDirectory
if ($LASTEXITCODE) { throw "CMake install failed." }

Copy-Item LICENSE, LICENSE_FFMPEG.md $OutputDirectory
& "$PSScriptRoot/create-build-info.ps1" -Variant $Variant -OutputPath "$OutputDirectory/BUILD_INFO.txt" -FFmpegRoot $ffmpegRoot

if ($Variant -eq "shared") {
	foreach ($pattern in "avformat-*.dll", "avcodec-*.dll", "avutil-*.dll", "swresample-*.dll", "swscale-*.dll") {
		$files = Get-ChildItem "$ffmpegRoot/bin" -Filter $pattern -File
		if (-not $files) { throw "Missing required shared FFmpeg runtime: $pattern" }
		Copy-Item $files.FullName $OutputDirectory
	}
} else {
	$buildInfo = Join-Path $ffmpegRoot "build-info"
	foreach ($name in "FFMPEG-COMMIT.txt", "FFMPEG-CONFIGURE.txt", "COPYING.LGPLv2.1", "LICENSE.md") {
		if (-not (Test-Path "$buildInfo/$name")) { throw "Missing static FFmpeg metadata: $name" }
		Copy-Item "$buildInfo/$name" $OutputDirectory
	}
}
