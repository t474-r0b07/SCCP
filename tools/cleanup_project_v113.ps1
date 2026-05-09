$ErrorActionPreference = "Stop"

Write-Host "== SCCP cleanup v1.1.3 ==" -ForegroundColor Cyan

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$foldersToClean = @(
  ".dart_tool",
  "build",
  "android\.gradle",
  "android\app\build",
  "windows\flutter\ephemeral"
)

$filesToRemove = @(
  ".flutter-plugins-dependencies",
  "create_all_files.sh",
  "summary.md",
  "flutter_01.png",
  "flutter_02.png"
)

foreach ($folder in $foldersToClean) {
  if (Test-Path $folder) {
    Write-Host "Removing folder: $folder" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $folder
  } else {
    Write-Host "Skip folder (not found): $folder" -ForegroundColor DarkGray
  }
}

foreach ($file in $filesToRemove) {
  if (Test-Path $file) {
    Write-Host "Removing file: $file" -ForegroundColor Yellow
    Remove-Item -Force $file
  } else {
    Write-Host "Skip file (not found): $file" -ForegroundColor DarkGray
  }
}

Write-Host "Cleanup complete." -ForegroundColor Green
