[CmdletBinding()]
param(
  [string]$BackendRoot = '',
  [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Resolve-BackendRoot {
  if (-not [string]::IsNullOrWhiteSpace($BackendRoot)) {
    return (Resolve-Path -LiteralPath $BackendRoot).Path
  }

  $repoRoot = Resolve-RepoRoot
  return (Resolve-Path -LiteralPath (Join-Path $repoRoot '.codex-backend-work\src')).Path
}

function ConvertTo-RelativeSqlPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $rootFull = [System.IO.Path]::GetFullPath($Root)
  if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $rootFull += [System.IO.Path]::DirectorySeparatorChar
  }

  $pathFull = [System.IO.Path]::GetFullPath($Path)
  $rootUri = [System.Uri]::new($rootFull)
  $pathUri = [System.Uri]::new($pathFull)
  $relative = [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString())
  return ($relative -replace '\\', '/')
}

function Get-AllSqlMigrations {
  param([Parameter(Mandatory = $true)][string]$Root)

  $modulesRoot = Join-Path $Root 'modules'
  if (-not (Test-Path -LiteralPath $modulesRoot -PathType Container)) {
    return @()
  }

  return @(
    Get-ChildItem -LiteralPath $modulesRoot -Recurse -Filter '*.sql' -File |
      ForEach-Object { ConvertTo-RelativeSqlPath -Root $Root -Path $_.FullName } |
      Where-Object { $_ -match '^modules/.+/sql/[^/]+\.sql$' } |
      Sort-Object -Unique
  )
}

function Invoke-GitPathList {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  Push-Location -LiteralPath $Root
  try {
    $output = & git @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return @($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  } finally {
    Pop-Location
  }
}

function Get-ChangedSqlMigrations {
  param([Parameter(Mandatory = $true)][string]$Root)

  $changed = Invoke-GitPathList -Root $Root -Arguments @(
    'diff',
    '--name-only',
    '--diff-filter=ACM',
    '--',
    'modules/**/sql/*.sql'
  )
  $untracked = Invoke-GitPathList -Root $Root -Arguments @(
    'ls-files',
    '--others',
    '--exclude-standard',
    '--',
    'modules/**/sql/*.sql'
  )

  return @(
    @($changed + $untracked) |
      Where-Object { $_ -match '^modules/.+/sql/[^/]+\.sql$' } |
      Sort-Object -Unique
  )
}

function Test-SqlMigration {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $failures = New-Object System.Collections.Generic.List[string]
  $localPath = Join-Path $Root ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
    $failures.Add("$RelativePath missing file")
    return $failures
  }

  $content = Get-Content -LiteralPath $localPath -Raw
  if ($content -notmatch '(?m)^-- \+migrate Up$') {
    $failures.Add("$RelativePath missing Up marker -- +migrate Up")
  }
  if ($content -notmatch '(?m)^-- \+migrate Down$') {
    $failures.Add("$RelativePath missing Down marker -- +migrate Down")
  }

  $isNewStyleDatedMigration = $RelativePath -match '^modules/.+/sql/.+-20[0-9]{6}-[0-9]{2}\.sql$'
  $createsIndex = $content -match '(?im)\bCREATE\s+(UNIQUE\s+)?INDEX\b'
  $hasIdempotentIndexGuard =
    $content -match '(?i)\binformation_schema\.STATISTICS\b' -or
    $content -match '(?i)\bIF\s+NOT\s+EXISTS\b'

  if ($isNewStyleDatedMigration -and $createsIndex -and -not $hasIdempotentIndexGuard) {
    $failures.Add("$RelativePath CREATE INDEX requires information_schema.STATISTICS or IF NOT EXISTS")
  }

  return $failures
}

$backendRootPath = Resolve-BackendRoot
$relativePaths = @(
  if ($All) {
    Get-AllSqlMigrations -Root $backendRootPath
  } else {
    Get-ChangedSqlMigrations -Root $backendRootPath
  }
)

Write-Host "phase6_sql_migration_lint_files=$($relativePaths.Count)"
$relativePaths | ForEach-Object { Write-Host $_ }

$allFailures = New-Object System.Collections.Generic.List[string]
foreach ($relativePath in $relativePaths) {
  $fileFailures = Test-SqlMigration -Root $backendRootPath -RelativePath $relativePath
  foreach ($failure in $fileFailures) {
    $allFailures.Add($failure)
    Write-Host "phase6_sql_migration_lint_failure=$failure"
  }
}

if ($allFailures.Count -gt 0) {
  Write-Host 'phase6_sql_migration_lint=fail'
  exit 1
}

Write-Host 'phase6_sql_migration_lint=pass'
exit 0
