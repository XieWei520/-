$scriptPath = Join-Path $PSScriptRoot '..\coturn_tls_probe.sh'

Describe 'coturn_tls_probe.sh source hardening' {
  BeforeAll {
    $script:Content = Get-Content -Path $scriptPath -Raw
  }

  It 'does not interpolate TURN host and realm into a double-quoted sh -lc TLS command' {
    $script:Content | Should Not Match 'sh\s+-lc\s+\\\s*\r?\n\s*"[\s\S]*openssl s_client -connect \$\{TURN_HOST\}:5349 -servername \$\{TURN_REALM\}'
    $script:Content | Should Not Match 'openssl s_client -connect \$\{TURN_HOST\}:5349 -servername \$\{TURN_REALM\}'
  }

  It 'passes TURN host and realm to the container shell as positional arguments' {
    $script:Content | Should Match 'sh\s+-lc\s+''[\s\S]*openssl s_client[\s\S]*''\s+sh\s+"\$\{TURN_HOST\}"\s+"\$\{TURN_REALM\}"'
  }

  It 'preserves the openssl s_client status instead of relying on head pipeline status' {
    $script:Content | Should Not Match 'openssl s_client[^\r\n|]*\|\s*head'
    $script:Content | Should Match 'openssl_status=\$\?'
    $script:Content | Should Match 'exit\s+"\$\{openssl_status\}"'
  }

  It 'redacts secret-like log fields with optional whitespace around separators' {
    $script:Content | Should Match '\(static-auth-secret\|realm\|user\|password\|secret\|key\)'
    $script:Content | Should Match '\[\[:space:\]\]\*\[:=\]\[\[:space:\]\]\*'
  }
}
