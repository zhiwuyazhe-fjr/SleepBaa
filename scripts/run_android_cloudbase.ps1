param(
  [string]$ConfigPath = ".cloudbase.local.json",
  [string]$Device = "android"
)

$ErrorActionPreference = "Stop"
# Flutter prints notices (e.g. mirror URL) to stderr; PS 7.2+ can treat that as a terminating error with -ErrorAction Stop.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-Config([string]$RepoRoot, [string]$RelativePath) {
  $fullPath = Join-Path $RepoRoot $RelativePath
  if (-not (Test-Path $fullPath)) {
    throw "CloudBase config file not found: $fullPath. Create it from .cloudbase.local.example.json first."
  }
  return (Get-Content -Path $fullPath -Raw | ConvertFrom-Json)
}

function Resolve-AndroidDevice([string]$RequestedDevice) {
  if (-not [string]::IsNullOrWhiteSpace($RequestedDevice) -and $RequestedDevice -ne "android") {
    return $RequestedDevice
  }

  # Use cmd so stderr (mirror / asset notices) is dropped reliably; stdout stays JSON only.
  $devicesText = cmd.exe /c "flutter devices --machine 2>nul"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$devicesText)) {
    throw "Unable to read flutter devices. Run `flutter devices` manually first."
  }

  $devices = $devicesText | ConvertFrom-Json
  $androidDevice = $devices | Where-Object {
    $_.targetPlatform -like "android-*"
  } | Select-Object -First 1

  if ($null -eq $androidDevice) {
    throw "No Android device detected. Connect a phone or start an emulator, then run `flutter devices`."
  }

  return [string]$androidDevice.id
}

$repoRoot = Get-RepoRoot
$config = Read-Config -RepoRoot $repoRoot -RelativePath $ConfigPath

$requiredKeys = @(
  "APP_BACKEND",
  "CLOUDBASE_ENV_ID",
  "CLOUDBASE_AUTH_BASE_URL",
  "CLOUDBASE_APP_API_BASE_URL",
  "CLOUDBASE_PUBLISHABLE_KEY"
)

foreach ($key in $requiredKeys) {
  $value = $config.$key
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Missing required CloudBase config field: $key"
  }
}

if ($config.CLOUDBASE_PUBLISHABLE_KEY -eq "PASTE_YOUR_PUBLISHABLE_KEY_HERE") {
  throw "Replace CLOUDBASE_PUBLISHABLE_KEY in .cloudbase.local.json with a real publishable key first."
}

Push-Location $repoRoot
try {
  $resolvedDevice = Resolve-AndroidDevice $Device
  Write-Host "Using Android device: $resolvedDevice"
  flutter run -d $resolvedDevice "--dart-define-from-file=$ConfigPath"
}
finally {
  Pop-Location
}
