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

  It 'normalizes and validates the release probe base URL before smoke and perf probes' {
    $content = Get-Content -Path $scriptPath -Raw

    $content | Should Match 'normalize_release_base_url\(\)'
    $content | Should Match 'assert_release_base_url_safe\s+"\$\{RELEASE_BASE_URL\}"'
    $content | Should Match '\$\{base_url,,\}'
    $content | Should Not Match '\[\[\s+"\$\{base_url\}"\s+==\s+http://\*'
    $content | Should Match 'smoke_test\.py\s+--base-url\s+"\$\{RELEASE_BASE_URL\}"'
    $content | Should Match 'perf_probe\.py\s+--base-url\s+"\$\{RELEASE_BASE_URL\}"'
  }
}
