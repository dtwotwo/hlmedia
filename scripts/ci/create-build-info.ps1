[CmdletBinding()]
param(
	[Parameter(Mandatory)][ValidateSet("shared", "game-static")][string]$Variant,
	[Parameter(Mandatory)][string]$OutputPath,
	[string]$FFmpegRoot
)

$ErrorActionPreference = "Stop"
$distribution = if ($Variant -eq "shared") { "SHARED" } else { "GAME" }
$linkage = if ($Variant -eq "shared") { "SHARED" } else { "STATIC" }
$ffmpegCommit = "not recorded by shared SDK"
if ($FFmpegRoot -and (Test-Path "$FFmpegRoot/build-info/FFMPEG-COMMIT.txt")) {
	$ffmpegCommit = (Get-Content "$FFmpegRoot/build-info/FFMPEG-COMMIT.txt" -Raw).Trim()
}
$ffmpegVersion = "unknown"
$versionHeader = Join-Path $FFmpegRoot "include/libavutil/ffversion.h"
if (Test-Path $versionHeader) {
	$versionMatch = [regex]::Match((Get-Content $versionHeader -Raw), '#define\s+FFMPEG_VERSION\s+"([^"]+)"')
	if ($versionMatch.Success) { $ffmpegVersion = $versionMatch.Groups[1].Value }
}
if ($Variant -eq "game-static" -and (Test-Path "deps/ffmpeg/VERSION")) {
	$pinParts = (Get-Content "deps/ffmpeg/VERSION" -Raw).Trim() -split "#", 2
	if ($pinParts.Count -eq 2) { $ffmpegVersion = $pinParts[1].Trim() }
}
$tag = if ($env:GITHUB_REF_TYPE -eq "tag") { $env:GITHUB_REF_NAME } else { (Get-Content haxelib.json -Raw | ConvertFrom-Json).version }
$runUrl = if ($env:GITHUB_SERVER_URL -and $env:GITHUB_REPOSITORY -and $env:GITHUB_RUN_ID) {
	"$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
} else { "local" }
$compiler = "MSVC"
$preset = if ($Variant -eq "shared") { "windows-shared" } else { "windows-game-static" }
$compilerFile = Get-ChildItem "out/build/$preset" -Filter CMakeCCompiler.cmake -File -Recurse | Select-Object -First 1
if ($compilerFile) {
	$compilerMatch = [regex]::Match((Get-Content $compilerFile.FullName -Raw), 'CMAKE_C_COMPILER_VERSION "([^"]+)"')
	if ($compilerMatch.Success) { $compiler = "MSVC $($compilerMatch.Groups[1].Value)" }
}

@"
hlmedia version or Git tag: $tag
hlmedia Git commit: $(git rev-parse HEAD)
build date UTC: $([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
target platform: Windows
target architecture: x64
distribution profile: $distribution
FFmpeg linkage type: $linkage
FFmpeg version: $ffmpegVersion
FFmpeg Git commit: $ffmpegCommit
CMake version: $((cmake --version | Select-Object -First 1))
compiler version: $compiler
GitHub Actions run URL: $runUrl
"@ | Set-Content $OutputPath -Encoding utf8
