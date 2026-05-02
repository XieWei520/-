$scriptPath = Join-Path $PSScriptRoot '..\remote_redeploy.sh'

Describe 'remote_redeploy.sh release probes' {
  It 'does not hard-code loopback HTTP for production smoke and perf probes' {
    $content = Get-Content -Path $scriptPath -Raw

    $content | Should Match 'RELEASE_BASE_URL'
    $content | Should Match 'TSDD_BASE_URL'
    $content | Should Match 'ALLOW_HTTP_RELEASE_PROBES'
    $content | Should Not Match 'smoke_test\.py --base-url http://127\.0\.0\.1'
    $content | Should Not Match 'perf_probe\.py --base-url http://127\.0\.0\.1'
  }
}