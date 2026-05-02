$scriptPath = Join-Path $PSScriptRoot '..\remote_redeploy.sh'

Describe 'remote_redeploy.sh release probes' {
  BeforeAll {
    function Get-TestBashPath {
      $bash = Get-Command bash -ErrorAction SilentlyContinue
      if ($bash) {
        return $bash.Source
      }

      $gitBash = 'D:\Apps\Git\bin\bash.exe'
      if (Test-Path $gitBash) {
        return $gitBash
      }

      throw 'bash was not found on PATH or at D:\Apps\Git\bin\bash.exe'
    }

    $script:BashPath = Get-TestBashPath
    $script:RemoteRedeployPath = ([System.IO.Path]::GetFullPath($scriptPath)) -replace '\\', '/'

    function Invoke-RemoteRedeployHelper {
      param(
        [Parameter(Mandatory)]
        [string] $FunctionName,

        [string[]] $Arguments = @(),

        [hashtable] $Environment = @{}
      )

      $bashScript = @'
set -euo pipefail
export REMOTE_REDEPLOY_HELPERS_ONLY=1
source "$1"
shift
helper="$1"
shift
"${helper}" "$@"
'@

      $oldEnvironment = @{}
      foreach ($key in $Environment.Keys) {
        $oldEnvironment[$key] = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, [string] $Environment[$key], 'Process')
      }

      try {
        $output = & $script:BashPath -c $bashScript bash $script:RemoteRedeployPath $FunctionName @Arguments 2>&1
        $exitCode = $LASTEXITCODE
      }
      finally {
        foreach ($key in $Environment.Keys) {
          [System.Environment]::SetEnvironmentVariable($key, $oldEnvironment[$key], 'Process')
        }
      }

      [pscustomobject] @{
        ExitCode = $exitCode
        Output = (($output | ForEach-Object { $_.ToString() }) -join "`n")
      }
    }
  }

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

  It 'preserves trailing slash in query values while normalizing release base URLs' {
    $result = Invoke-RemoteRedeployHelper `
      -FunctionName 'normalize_release_base_url' `
      -Arguments @('https://example.com/path?next=/foo/')

    $result.ExitCode | Should Be 0
    $result.Output | Should Be 'https://example.com/path?next=/foo/'
  }

  It 'preserves trailing slash in fragments while normalizing release base URLs' {
    $result = Invoke-RemoteRedeployHelper `
      -FunctionName 'normalize_release_base_url' `
      -Arguments @('https://example.com/path#frag/')

    $result.ExitCode | Should Be 0
    $result.Output | Should Be 'https://example.com/path#frag/'
  }

  It 'removes inline comments outside quotes before unquoting release base URLs' {
    $result = Invoke-RemoteRedeployHelper `
      -FunctionName 'normalize_release_base_url' `
      -Arguments @(' "HTTP://127.0.0.1/" # local ')

    $result.ExitCode | Should Be 0
    $result.Output | Should Be 'HTTP://127.0.0.1'
  }

  It 'rejects HTTP release probe URLs unless local diagnostics are explicitly allowed' {
    $result = Invoke-RemoteRedeployHelper `
      -FunctionName 'assert_release_base_url_safe' `
      -Arguments @('HTTP://127.0.0.1') `
      -Environment @{ ALLOW_HTTP_RELEASE_PROBES = '0' }

    $result.ExitCode | Should Not Be 0
    $result.Output | Should Match 'Refusing production release probes over HTTP'

    $allowed = Invoke-RemoteRedeployHelper `
      -FunctionName 'assert_release_base_url_safe' `
      -Arguments @('HTTP://127.0.0.1') `
      -Environment @{ ALLOW_HTTP_RELEASE_PROBES = '1' }

    $allowed.ExitCode | Should Be 0
  }
}
