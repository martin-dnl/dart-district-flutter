param(
  [ValidateSet('android', 'ios')]
  [string]$Platform = 'android',

  [ValidateSet('none', 'patch', 'minor', 'major')]
  [string]$IncrementVersion = 'patch',

  [switch]$DryRun,
  [switch]$SkipPubspecUpdate,
  [switch]$SkipDbApply,

  [string]$MinVersion,
  [string]$RecommendedVersion,
  [int]$MinBuild,
  [int]$RecommendedBuild,

  [string]$StoreUrlAndroid = 'https://play.google.com/store/apps/details?id=fr.dartdistrict.mobile',
  [string]$StoreUrlIos = '',

  [string]$ForceMessage,
  [string]$SoftMessage,

  [string]$DatabaseUrl,
  [string]$EnvFile = 'backend/.env.prod'
)

$ErrorActionPreference = 'Stop'

function Escape-SqlLiteral {
  param([string]$Value)
  if ($null -eq $Value) { return 'NULL' }
  return "'" + ($Value -replace "'", "''") + "'"
}

function Parse-AppVersion {
  param([string]$PubspecPath)

  $versionLine = Get-Content $PubspecPath | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
  if (-not $versionLine) {
    throw 'Ligne version introuvable dans pubspec.yaml'
  }

  $raw = ($versionLine -replace '^version:\s*', '').Trim()
  if ($raw -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
    throw "Format version invalide: $raw"
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

function Bump-VersionName {
  param([pscustomobject]$Current, [string]$Mode)

  switch ($Mode) {
    'none'  { return $Current.Name }
    'patch' { return "$($Current.Major).$($Current.Minor).$($Current.Patch + 1)" }
    'minor' { return "$($Current.Major).$($Current.Minor + 1).0" }
    'major' { return "$($Current.Major + 1).0.0" }
    default { return $Current.Name }
  }
}

function Parse-DotEnv {
  param([string]$Path)

  $map = @{}
  if (!(Test-Path $Path)) {
    return $map
  }

  foreach ($line in Get-Content $Path) {
    $trim = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith('#')) { continue }
    $idx = $trim.IndexOf('=')
    if ($idx -lt 1) { continue }
    $k = $trim.Substring(0, $idx).Trim()
    $v = $trim.Substring($idx + 1).Trim()
    $map[$k] = $v
  }

  return $map
}

function Resolve-DbConnection {
  param(
    [string]$DbUrl,
    [hashtable]$EnvMap
  )

  if (-not [string]::IsNullOrWhiteSpace($DbUrl)) {
    return [pscustomobject]@{ Mode = 'url'; Url = $DbUrl }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:DATABASE_URL)) {
    return [pscustomobject]@{ Mode = 'url'; Url = $env:DATABASE_URL }
  }

  $required = @('POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB')
  $missing = @($required | Where-Object { -not $EnvMap.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($EnvMap[$_]) })
  if ($missing.Count -gt 0) {
    throw "Variables DB manquantes dans env: $($missing -join ', ')"
  }

  return [pscustomobject]@{
    Mode = 'params'
    Host = $EnvMap['POSTGRES_HOST']
    Port = $EnvMap['POSTGRES_PORT']
    User = $EnvMap['POSTGRES_USER']
    Password = $EnvMap['POSTGRES_PASSWORD']
    Database = $EnvMap['POSTGRES_DB']
  }
}

function Invoke-PsqlSql {
  param(
    [pscustomobject]$Connection,
    [string]$Sql,
    [switch]$TuplesOnly
  )

  $psql = Get-Command psql -ErrorAction SilentlyContinue
  if ($psql) {
    $args = @('-v', 'ON_ERROR_STOP=1')
    if ($TuplesOnly) { $args += @('-t', '-A') }
    $args += @('-c', $Sql)

    if ($Connection.Mode -eq 'url') {
      return & psql $Connection.Url @args
    }

    $env:PGHOST = $Connection.Host
    $env:PGPORT = $Connection.Port
    $env:PGUSER = $Connection.User
    $env:PGPASSWORD = $Connection.Password
    return & psql -d $Connection.Database @args
  }

  # Fallback: use Node.js + pg from backend dependencies.
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    throw 'Ni psql ni node ne sont disponibles. Installe psql ou Node.js.'
  }

  $backendDir = Join-Path $repoRoot 'backend'
  $tempJs = Join-Path $backendDir (".tmp-set-app-version-policy-v3-{0}.cjs" -f ([guid]::NewGuid().ToString('N')))
  $tempOut = [System.IO.Path]::GetTempFileName() + '.txt'
  $tempErr = [System.IO.Path]::GetTempFileName() + '.txt'

  $nodeScript = @"
const fs = require('fs');
const { Client } = require('pg');

async function main() {
  const sql = fs.readFileSync(process.env.COPILOT_SQL_PATH, 'utf8');
  let config;

  if (process.env.COPILOT_DB_MODE === 'url') {
    config = { connectionString: process.env.COPILOT_DB_URL };
  } else {
    config = {
      host: process.env.COPILOT_DB_HOST,
      port: Number(process.env.COPILOT_DB_PORT),
      user: process.env.COPILOT_DB_USER,
      password: process.env.COPILOT_DB_PASSWORD,
      database: process.env.COPILOT_DB_NAME,
    };
  }

  const client = new Client(config);
  await client.connect();
  const result = await client.query(sql);
  await client.end();

  const tuplesOnly = process.env.COPILOT_TUPLES_ONLY === '1';
  if (tuplesOnly) {
    const lines = (result.rows || []).map((row) => Object.values(row).join('|'));
    fs.writeFileSync(process.env.COPILOT_OUT_PATH, lines.join('\n'), 'utf8');
  } else {
    fs.writeFileSync(process.env.COPILOT_OUT_PATH, String(result.rowCount ?? 0), 'utf8');
  }
}

main().catch((error) => {
  console.error(error?.message || error);
  process.exit(1);
});
"@

  Set-Content -Path $tempJs -Value $nodeScript -Encoding UTF8

  $sqlFile = [System.IO.Path]::GetTempFileName() + '.sql'
  Set-Content -Path $sqlFile -Value $Sql -Encoding UTF8

  $env:COPILOT_SQL_PATH = $sqlFile
  $env:COPILOT_OUT_PATH = $tempOut
  $env:COPILOT_TUPLES_ONLY = if ($TuplesOnly) { '1' } else { '0' }

  if ($Connection.Mode -eq 'url') {
    $env:COPILOT_DB_MODE = 'url'
    $env:COPILOT_DB_URL = $Connection.Url
  } else {
    $env:COPILOT_DB_MODE = 'params'
    $env:COPILOT_DB_HOST = $Connection.Host
    $env:COPILOT_DB_PORT = $Connection.Port
    $env:COPILOT_DB_USER = $Connection.User
    $env:COPILOT_DB_PASSWORD = $Connection.Password
    $env:COPILOT_DB_NAME = $Connection.Database
  }

  try {
    Push-Location $backendDir
    & node $tempJs 2> $tempErr
    $exitCode = $LASTEXITCODE
    Pop-Location

    if ($exitCode -ne 0) {
      $details = ''
      if (Test-Path $tempErr) {
        $details = (Get-Content $tempErr -ErrorAction SilentlyContinue | Out-String).Trim()
      }
      if ([string]::IsNullOrWhiteSpace($details)) {
        throw 'Execution SQL via Node/pg a echoue.'
      }
      throw "Execution SQL via Node/pg a echoue: $details"
    }

    if (Test-Path $tempOut) {
      return Get-Content $tempOut
    }

    return @()
  } finally {
    if (Test-Path $tempJs) { Remove-Item $tempJs -Force }
    if (Test-Path $sqlFile) { Remove-Item $sqlFile -Force }
    if (Test-Path $tempOut) { Remove-Item $tempOut -Force }
    if (Test-Path $tempErr) { Remove-Item $tempErr -Force }
    Remove-Item Env:COPILOT_SQL_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_OUT_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_TUPLES_ONLY -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_URL -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_HOST -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_PORT -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_USER -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:COPILOT_DB_NAME -ErrorAction SilentlyContinue
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$preferredEnvPath = Join-Path $repoRoot $EnvFile
$fallbackEnvPath = Join-Path $repoRoot 'backend/.env'

$current = Parse-AppVersion -PubspecPath $pubspecPath
$nextVersionDefault = Bump-VersionName -Current $current -Mode $IncrementVersion
$nextBuildDefault = $current.Build + 1

$resolvedMinVersion = if ($MinVersion) { $MinVersion } else { $current.Name }
$resolvedRecommendedVersion = if ($RecommendedVersion) { $RecommendedVersion } else { $nextVersionDefault }
$resolvedMinBuild = if ($PSBoundParameters.ContainsKey('MinBuild')) { $MinBuild } else { $current.Build }
$resolvedRecommendedBuild = if ($PSBoundParameters.ContainsKey('RecommendedBuild')) { $RecommendedBuild } else { $nextBuildDefault }

$resolvedForceMessage = if ($ForceMessage) {
  $ForceMessage
} else {
  "Mise a jour obligatoire. Version/build minimum: $resolvedMinVersion+$resolvedMinBuild"
}

$resolvedSoftMessage = if ($SoftMessage) {
  $SoftMessage
} else {
  "Nouvelle version disponible: $resolvedRecommendedVersion+$resolvedRecommendedBuild"
}

$envPathUsed = if (Test-Path $preferredEnvPath) { $preferredEnvPath } else { $fallbackEnvPath }
$envMap = Parse-DotEnv -Path $envPathUsed
$connection = Resolve-DbConnection -DbUrl $DatabaseUrl -EnvMap $envMap

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
  min_build,
  recommended_build,
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
  $resolvedMinBuild,
  $resolvedRecommendedBuild,
  $(Escape-SqlLiteral $StoreUrlAndroid),
  $(Escape-SqlLiteral $StoreUrlIos),
  $(Escape-SqlLiteral $resolvedForceMessage),
  $(Escape-SqlLiteral $resolvedSoftMessage),
  TRUE
);

COMMIT;
"@

Write-Host '=== App Version Policy V3 ===' -ForegroundColor Cyan
Write-Host "Env file:               $envPathUsed"
Write-Host "Platform:               $Platform"
Write-Host "pubspec actuel:         $($current.Raw)"
Write-Host "min version/build:      $resolvedMinVersion+$resolvedMinBuild"
Write-Host "recommended version/build: $resolvedRecommendedVersion+$resolvedRecommendedBuild"
Write-Host "Action DB:              $(if ($SkipDbApply) { 'skip' } else { 'apply' })"
Write-Host "Action pubspec:         $(if ($SkipPubspecUpdate) { 'skip' } else { 'update' })"
Write-Host ''

if ($DryRun) {
  Write-Host 'DRY-RUN SQL:' -ForegroundColor Yellow
  Write-Output $sql
  Write-Host ''
  Write-Host 'Commande execution directe:' -ForegroundColor Yellow
  Write-Host ".\scripts\set-app-version-policy-v3.ps1 -Platform $Platform -IncrementVersion $IncrementVersion"
  exit 0
}

if (-not $SkipDbApply) {
  Write-Host 'Application policy en DB...' -ForegroundColor Green
  Invoke-PsqlSql -Connection $connection -Sql $sql | Out-Null
  Write-Host 'DB OK: nouvelle policy active inseree.' -ForegroundColor Green
}

if (-not $SkipPubspecUpdate) {
  $nextPubspec = "$resolvedRecommendedVersion+$resolvedRecommendedBuild"
  $content = Get-Content $pubspecPath
  $updated = $content | ForEach-Object {
    if ($_ -match '^version:\s*') { "version: $nextPubspec" } else { $_ }
  }
  Set-Content -Path $pubspecPath -Value $updated -Encoding UTF8
  Write-Host "pubspec.yaml incrementé -> version: $nextPubspec" -ForegroundColor Green
}

Write-Host 'V3 terminee.' -ForegroundColor Green
