param(
  [ValidateSet('android', 'ios')]
  [string]$Platform = 'android',

  [ValidateSet('none', 'patch', 'minor', 'major')]
  [string]$IncrementVersion = 'patch',

  [switch]$Apply,
  [switch]$UpdatePubspec,
  [switch]$NonInteractive,

  [string]$MinVersion,
  [string]$RecommendedVersion,
  [int]$RecommendedBuild,

  [string]$StoreUrlAndroid = 'https://play.google.com/store/apps/details?id=fr.dartdistrict.mobile',
  [string]$StoreUrlIos = '',

  [string]$ForceMessage,
  [string]$SoftMessage,

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
    Line = $versionLine
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

function Parse-DotEnv {
  param([string]$EnvPath)

  $map = @{}
  if (!(Test-Path $EnvPath)) {
    return $map
  }

  foreach ($line in Get-Content $EnvPath) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) { continue }

    $key = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    $map[$key] = $value
  }

  return $map
}

function Get-ConnectionMode {
  param(
    [string]$DbUrl,
    [hashtable]$EnvMap
  )

  if (-not [string]::IsNullOrWhiteSpace($DbUrl)) {
    return [pscustomobject]@{
      Mode = 'url'
      Url = $DbUrl
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:DATABASE_URL)) {
    return [pscustomobject]@{
      Mode = 'url'
      Url = $env:DATABASE_URL
    }
  }

  $required = @('POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB')
  $missing = @($required | Where-Object { -not $EnvMap.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($EnvMap[$_]) })
  if ($missing.Count -gt 0) {
    throw "Impossible de construire la connexion DB. Manque: $($missing -join ', ')"
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
  if (-not $psql) {
    throw 'psql introuvable dans le PATH. Installe PostgreSQL client ou ajoute psql.exe au PATH.'
  }

  $args = @('-v', 'ON_ERROR_STOP=1')
  if ($TuplesOnly) {
    $args += @('-t', '-A')
  }
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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$backendEnvPath = Join-Path $repoRoot 'backend/.env'

$appVersion = Parse-AppVersion -PubspecPath $pubspecPath
$recommendedVersionDefault = Get-BumpedVersion -Major $appVersion.Major -Minor $appVersion.Minor -Patch $appVersion.Patch -Mode $IncrementVersion
$recommendedBuildDefault = $appVersion.Build + 1

$resolvedMinVersion = if ($MinVersion) { $MinVersion } else { $appVersion.Name }
$resolvedRecommendedVersion = if ($RecommendedVersion) { $RecommendedVersion } else { $recommendedVersionDefault }
$resolvedRecommendedBuild = if ($PSBoundParameters.ContainsKey('RecommendedBuild')) { $RecommendedBuild } else { $recommendedBuildDefault }

if (-not $NonInteractive) {
  Write-Host '=== App Version Policy V2 ===' -ForegroundColor Cyan
  Write-Host "Platform:               $Platform"
  Write-Host "pubspec version:        $($appVersion.Raw)"
  Write-Host "Version actuelle:       $($appVersion.Name)"
  Write-Host "Build actuel (Play):    $($appVersion.Build)"
  Write-Host "Proposition version:    $resolvedRecommendedVersion"
  Write-Host "Proposition build:      $resolvedRecommendedBuild"
  Write-Host ''

  $confirm = Read-Host 'Confirmer ces valeurs ? (Y/n)'
  if ($confirm -and $confirm.Trim().ToLower() -eq 'n') {
    throw 'Operation annulee par l utilisateur.'
  }
}

$resolvedForceMessage = if ($ForceMessage) {
  $ForceMessage
} else {
  "Mise a jour obligatoire. Version minimum: $resolvedMinVersion. Build actuel: $($appVersion.Build)."
}

$resolvedSoftMessage = if ($SoftMessage) {
  $SoftMessage
} else {
  "Nouvelle version recommandee: $resolvedRecommendedVersion (build cible: $resolvedRecommendedBuild)."
}

$envMap = Parse-DotEnv -EnvPath $backendEnvPath
$connection = Get-ConnectionMode -DbUrl $DatabaseUrl -EnvMap $envMap

$existingPolicySql = @"
SELECT min_version || '|' || recommended_version || '|' || updated_at
FROM app_version_policies
WHERE platform = '$(($Platform -replace "'", "''"))'
  AND is_active = TRUE
ORDER BY updated_at DESC
LIMIT 1;
"@

$existingPolicyRaw = ''
try {
  $existingPolicyRaw = (Invoke-PsqlSql -Connection $connection -Sql $existingPolicySql -TuplesOnly) -join "`n"
} catch {
  $existingPolicyRaw = ''
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

Write-Host ''
Write-Host 'Policy active actuelle:' -ForegroundColor Yellow
if ([string]::IsNullOrWhiteSpace($existingPolicyRaw)) {
  Write-Host '  (aucune policy active detectee ou DB inaccessible en lecture)'
} else {
  Write-Host "  $existingPolicyRaw"
}

Write-Host ''
Write-Host 'Nouvelle policy cible:' -ForegroundColor Green
Write-Host "  min_version:         $resolvedMinVersion"
Write-Host "  recommended_version: $resolvedRecommendedVersion"
Write-Host "  recommended_build:   $resolvedRecommendedBuild"

if (-not $Apply) {
  Write-Host ''
  Write-Host 'Mode DRY-RUN (SQL genere):' -ForegroundColor Yellow
  Write-Output $sql
  Write-Host ''
  Write-Host 'Pour appliquer en one-shot:' -ForegroundColor Yellow
  Write-Host "  .\scripts\set-app-version-policy-v2.ps1 -Platform $Platform -IncrementVersion $IncrementVersion -Apply"
  Write-Host 'Pour appliquer + maj pubspec:' -ForegroundColor Yellow
  Write-Host "  .\scripts\set-app-version-policy-v2.ps1 -Platform $Platform -IncrementVersion $IncrementVersion -Apply -UpdatePubspec"
  exit 0
}

Write-Host ''
Write-Host 'Application SQL en cours...' -ForegroundColor Green
Invoke-PsqlSql -Connection $connection -Sql $sql | Out-Null
Write-Host 'Policy app_version_policies appliquee.' -ForegroundColor Green

if ($UpdatePubspec) {
  $nextPubspecVersion = "$resolvedRecommendedVersion+$resolvedRecommendedBuild"
  $current = Get-Content $pubspecPath
  $updated = $current | ForEach-Object {
    if ($_ -match '^version:\s*') {
      "version: $nextPubspecVersion"
    } else {
      $_
    }
  }
  Set-Content -Path $pubspecPath -Value $updated -Encoding UTF8
  Write-Host "pubspec.yaml mis a jour -> version: $nextPubspecVersion" -ForegroundColor Green
}

Write-Host 'Termine.' -ForegroundColor Green
