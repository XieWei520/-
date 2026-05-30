[CmdletBinding()]
param(
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$PrometheusUrl = 'http://127.0.0.1:9090',
  [switch]$Run
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$queryTemplates = @(
  'up{job="wukongim_api"}',
  'sum by (status_class) (increase(wukongim_http_requests_total[__WINDOW__]))',
  'topk(20, sum by (route, method) (increase(wukongim_http_requests_total[__WINDOW__])))',
  'histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[__WINDOW__])))',
  'histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[__WINDOW__])))',
  'sum(increase(wukongim_http_requests_total{route="unknown"}[__WINDOW__]))'
)

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)

  $singleQuote = [string][char]39
  $doubleQuote = [string][char]34
  $escapedSingleQuote = $singleQuote + $doubleQuote + $singleQuote + $doubleQuote + $singleQuote
  return $singleQuote + $Value.Replace($singleQuote, $escapedSingleQuote) + $singleQuote
}

Write-Host 'p95_regression_threshold=1.5'
Write-Host 'p99_regression_threshold=1.5'
Write-Host 'rollback_if_5xx_increase=true'
Write-Host 'rollback_if_unknown_route_increase=true'

foreach ($window in @('5m', '30m')) {
  Write-Host "window=$window"
  foreach ($template in $queryTemplates) {
    Write-Host ($template.Replace('__WINDOW__', $window))
  }
}

if (-not $Run) {
  Write-Host 'Dry run only. Add -Run to query Prometheus through the remote SSH host.'
  Write-Host 'phase6_prometheus_gate_report=completed'
  exit 0
}

$trimmedPrometheusUrl = $PrometheusUrl.TrimEnd('/')

foreach ($window in @('5m', '30m')) {
  Write-Host "prometheus_query_window=$window"
  foreach ($template in $queryTemplates) {
    $query = $template.Replace('__WINDOW__', $window)
    $encodedQuery = [uri]::EscapeDataString($query)
    $queryUrl = "$trimmedPrometheusUrl/api/v1/query?query=$encodedQuery"
    $remoteCommand = 'curl -fsS ' + (Quote-Bash -Value $queryUrl)

    Write-Host "query=$query"
    & ssh -- $RemoteHost $remoteCommand
    if ($LASTEXITCODE -ne 0) {
      throw "Prometheus query failed for window=$window query=$query"
    }
  }
}

Write-Host 'phase6_prometheus_gate_report=completed'
exit 0
