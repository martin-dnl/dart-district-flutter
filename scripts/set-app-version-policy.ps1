param(
  [ValidateSet('android', 'ios')]
  [string]$Platform = 'android',

  [ValidateSet('none', 'patch', 'minor', 'major')]
  [string]$Increment = 'patch',

  [string]$MinVersion,
  [string]$RecommendedVersion,

  [string]$StoreUrlAndroid = 'https://play.google.com/store/apps/details?id=fr.dartdistrict.mobile',
  [string]$StoreUrlIos = '',

  [string]$ForceMessage,
  [string]$SoftMessage,

  [switch]$Apply,
  [string]$DatabaseUrl
)

$ErrorActionPreference = 'Stop'

function Escape-SqlLiteral {
  param([string]$Value)
  if ($null -eq $Value) { return 'NULL' }
  return "'" + ($Value -replace "'", "''") + "'"
}

function Parse-AppVersion {
  param([string]$PubspecPath)

  if (!(Test-Path $PubspecPath)) {
    throw "pubspec.yaml introuvable: $PubspecPath"
  }

  $versionLine = Get-Content $PubspecPath | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
  if (-not $versionLine) {
    throw 'Ligne version: introuvable dans pubspec.yaml'
  }

  $raw = ($versionLine -replace '^version:\s*', '').Trim()
  if ($raw -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
    throw "Format version invalide dans pubspec.yaml: $raw"
  }

  return [pscustomobject]@{
    Name = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
    Build = [int]$Matches[4]
    Major = [int]$Matches[1]
    Minor = [int]$Matches[2]
    Patch = [int]$Matches[3]
    Raw = $raw
  }
}

function Get-BumpedVersion {
  param(
    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [string]$Mode
  )

  switch ($Mode) {
    'none'  { return "$Major.$Minor.$Patch" }
    'patch' { return "$Major.$Minor.$($Patch + 1)" }
    'minor' { return "$Major.$($Minor + 1).0" }
    'major' { return "$($Major + 1).0.0" }
    default { return "$Major.$Minor.$Patch" }
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$appVersion = Parse-AppVersion -PubspecPath $pubspecPath

$resolvedMinVersion = if ($MinVersion) { $MinVersion } else { $appVersion.Name }
$resolvedRecommendedVersion = if ($RecommendedVersion) {
  $RecommendedVersion
} else {
  Get-BumpedVersion -Major $appVersion.Major -Minor $appVersion.Minor -Patch $appVersion.Patch -Mode $Increment
}

$resolvedForceMessage = if ($ForceMessage) {
  $ForceMessage
} else {
  "Une mise a jour est obligatoire pour continuer. Build actuel: $($appVersion.Build)."
}

$resolvedSoftMessage = if ($SoftMessage) {
  $SoftMessage
} else {
  "Une nouvelle version est disponible. Build actuel: $($appVersion.Build)."
}

$sql = @"
BEGIN;

UPDATE app_version_policies
SET is_active = FALSE,
    updated_at = NOW()
WHERE platform = $(Escape-SqlLiteral $Platform)
  AND is_active = TRUE;

INSERT INTO app_version_policies (
  platform,
  min_version,
  recommended_version,
  store_url_android,
  store_url_ios,
  message_force_update,
  message_soft_update,
  is_active
)
VALUES (
  $(Escape-SqlLiteral $Platform),
  $(Escape-SqlLiteral $resolvedMinVersion),
  $(Escape-SqlLiteral $resolvedRecommendedVersion),
  $(Escape-SqlLiteral $StoreUrlAndroid),
  $(Escape-SqlLiteral $StoreUrlIos),
  $(Escape-SqlLiteral $resolvedForceMessage),
  $(Escape-SqlLiteral $resolvedSoftMessage),
  TRUE
);

COMMIT;
"@

Write-Host '=== App Version Policy Builder ===' -ForegroundColor Cyan
Write-Host "Platform:               $Platform"
Write-Host "pubspec version:        $($appVersion.Raw)"
Write-Host "Version actuelle:       $($appVersion.Name)"
Write-Host "Build actuel (Play):    $($appVersion.Build)"
Write-Host "Min version retenue:    $resolvedMinVersion"
Write-Host "Recommended retenue:    $resolvedRecommendedVersion"
Write-Host "Increment logique:      $Increment"
Write-Host ''

if (-not $Apply) {
  Write-Host 'Mode DRY-RUN (aucune ecriture DB):' -ForegroundColor Yellow
  Write-Output $sql
  Write-Host ''
  Write-Host 'Pour appliquer:' -ForegroundColor Yellow
  Write-Host '  1) set DATABASE_URL=postgresql://user:password@host:5432/dbname'
  Write-Host "  2) .\scripts\set-app-version-policy.ps1 -Platform $Platform -Increment $Increment -Apply"
  exit 0
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
  throw 'psql introuvable dans le PATH. Installe PostgreSQL client ou ajoute psql.exe au PATH.'
}

$effectiveDbUrl = if ($DatabaseUrl) { $DatabaseUrl } elseif ($env:DATABASE_URL) { $env:DATABASE_URL } else { '' }
if ([string]::IsNullOrWhiteSpace($effectiveDbUrl)) {
  throw 'DATABASE_URL manquant. Passe -DatabaseUrl ou exporte DATABASE_URL avant -Apply.'
}

$tempSql = [System.IO.Path]::GetTempFileName() + '.sql'
Set-Content -Path $tempSql -Value $sql -Encoding UTF8

try {
  Write-Host 'Application SQL en cours...' -ForegroundColor Green
  & psql "$effectiveDbUrl" -v ON_ERROR_STOP=1 -f $tempSql
  Write-Host 'Policy appliquee avec succes.' -ForegroundColor Green
} finally {
  if (Test-Path $tempSql) {
    Remove-Item $tempSql -Force
  }
}
