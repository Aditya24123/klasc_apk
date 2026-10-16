param([switch]$Debug)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Install Flutter and add its bin directory to PATH. See README.md.'
}
Push-Location $PSScriptRoot
try {
    $buildMode = if ($Debug) { 'debug' } else { 'release' }
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
    & flutter build apk "--$buildMode"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    $versionLine = Get-Content pubspec.yaml | Where-Object { $_ -match '^version:' }
    $appVersion = (($versionLine -replace '^version:\s*', '') -split '\+')[0].Trim()
    New-Item -ItemType Directory -Force -Path dist | Out-Null
    $destination = Join-Path $PSScriptRoot "dist/KLASC-$appVersion-$buildMode.apk"
    Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$buildMode.apk" -Destination $destination -Force
    Write-Host "APK ready: $destination"
} finally {
    Pop-Location
}
