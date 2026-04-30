$utilsPath = Join-Path $PSScriptRoot '..\windows_tunnel_client_process_utils.ps1'

if (Test-Path $utilsPath) {
  . $utilsPath
}

Describe 'windows_tunnel_client_process_utils.ps1' {
  It 'exists' {
    (Test-Path $utilsPath) | Should Be $true
  }

  Context 'Test-CommandLineMatchesAnyPattern' {
    It 'matches when any configured substring is present' {
      if (-not (Get-Command Test-CommandLineMatchesAnyPattern -ErrorAction SilentlyContinue)) {
        throw 'Test-CommandLineMatchesAnyPattern is missing.'
      }

      $result = Test-CommandLineMatchesAnyPattern `
        -CommandLine 'ssh.exe -L 15001:172.18.0.9:8090 -N ubuntu@42.194.218.158' `
        -Patterns @('-L 15001:172.18.0.9:8090', '-L 15100:172.18.0.6:5100')

      $result | Should Be $true
    }

    It 'returns false when the command line is empty' {
      if (-not (Get-Command Test-CommandLineMatchesAnyPattern -ErrorAction SilentlyContinue)) {
        throw 'Test-CommandLineMatchesAnyPattern is missing.'
      }

      $result = Test-CommandLineMatchesAnyPattern -CommandLine $null -Patterns @('wukong_tcp_probe')

      $result | Should Be $false
    }
  }

  Context 'Get-DescendantProcessIds' {
    It 'returns all descendants recursively' {
      if (-not (Get-Command Get-DescendantProcessIds -ErrorAction SilentlyContinue)) {
        throw 'Get-DescendantProcessIds is missing.'
      }

      $processes = @(
        [pscustomobject]@{ ProcessId = 11736; ParentProcessId = 1; Name = 'cmd.exe'; CommandLine = 'cmd.exe /c dart.bat run wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 23104; ParentProcessId = 11736; Name = 'dart.exe'; CommandLine = 'dart.exe run wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 24352; ParentProcessId = 23104; Name = 'dartvm.exe'; CommandLine = 'dartvm.exe wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 20344; ParentProcessId = 24352; Name = 'conhost.exe'; CommandLine = 'conhost.exe' }
        [pscustomobject]@{ ProcessId = 99999; ParentProcessId = 1; Name = 'ssh.exe'; CommandLine = 'ssh.exe ubuntu@other-host' }
      )

      $result = Get-DescendantProcessIds -Processes $processes -ParentIds @(11736)

      ($result | Sort-Object) -join ',' | Should Be '20344,23104,24352'
    }
  }

  Context 'Resolve-WindowsTunnelRemoteTarget' {
    It 'resolves a container IP into an SSH tunnel target' {
      if (-not (Get-Command Resolve-WindowsTunnelRemoteTarget -ErrorAction SilentlyContinue)) {
        throw 'Resolve-WindowsTunnelRemoteTarget is missing.'
      }

      $result = Resolve-WindowsTunnelRemoteTarget `
        -DefaultRemote '127.0.0.1:5100' `
        -ContainerName 'wukongim_prod-wukongim-1' `
        -ContainerPort 5100 `
        -ContainerIpResolver { param($ContainerName) '172.18.0.6' }

      $result | Should Be '172.18.0.6:5100'
    }

    It 'rejects invalid container IP resolver output' {
      if (-not (Get-Command Resolve-WindowsTunnelRemoteTarget -ErrorAction SilentlyContinue)) {
        throw 'Resolve-WindowsTunnelRemoteTarget is missing.'
      }

      {
        Resolve-WindowsTunnelRemoteTarget `
          -DefaultRemote '127.0.0.1:5100' `
          -ContainerName 'wukongim_prod-wukongim-1' `
          -ContainerPort 5100 `
          -ContainerIpResolver { param($ContainerName) 'not-an-ip' }
      } | Should Throw 'Unable to resolve'
    }
  }

  Context 'Get-WindowsTunnelClientStopRecords' {
    It 'selects matched roots and their descendants exactly once' {
      if (-not (Get-Command Get-WindowsTunnelClientProcessRules -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientProcessRules is missing.'
      }

      if (-not (Get-Command Get-WindowsTunnelClientStopRecords -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientStopRecords is missing.'
      }

      $processes = @(
        [pscustomobject]@{ ProcessId = 4900; ParentProcessId = 1; Name = 'powershell.exe'; CommandLine = 'powershell.exe -Command flutter run --dart-define=WK_DEV_BASE_URL=http://127.0.0.1:15001 --dart-define=WK_DEV_WS_ADDR=127.0.0.1:15100' }
        [pscustomobject]@{ ProcessId = 10612; ParentProcessId = 4900; Name = 'ssh.exe'; CommandLine = 'ssh.exe -L 15001:172.18.0.9:8090 -L 15100:172.18.0.6:5100 -N ubuntu@42.194.218.158' }
        [pscustomobject]@{ ProcessId = 11736; ParentProcessId = 1; Name = 'cmd.exe'; CommandLine = 'cmd.exe /c dart.bat run C:\Users\COLORFUL\AppData\Local\Temp\wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 23104; ParentProcessId = 11736; Name = 'dart.exe'; CommandLine = 'dart.exe run C:\Users\COLORFUL\AppData\Local\Temp\wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 24352; ParentProcessId = 23104; Name = 'dartvm.exe'; CommandLine = 'dartvm.exe --resolved_executable_name=dart.exe wukong_tcp_probe.dart' }
        [pscustomobject]@{ ProcessId = 30000; ParentProcessId = 1; Name = 'wukong_im_app.exe'; CommandLine = 'C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\wukong_im_app.exe' }
        [pscustomobject]@{ ProcessId = 31000; ParentProcessId = 1; Name = 'InfoEquity.exe'; CommandLine = 'C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\InfoEquity.exe' }
        [pscustomobject]@{ ProcessId = 40000; ParentProcessId = 1; Name = 'ssh.exe'; CommandLine = 'ssh.exe ubuntu@other-host' }
      )

      $rules = Get-WindowsTunnelClientProcessRules -ApiLocalPort 15001 -ImLocalPort 15100
      $result = Get-WindowsTunnelClientStopRecords -Processes $processes -Rules $rules

      ($result.ProcessId | Sort-Object) -join ',' | Should Be '4900,10612,11736,23104,24352,30000,31000'
    }

    It 'selects an SSH tunnel by local forwarded ports when remote container IPs drift' {
      if (-not (Get-Command Get-WindowsTunnelClientProcessRules -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientProcessRules is missing.'
      }

      if (-not (Get-Command Get-WindowsTunnelClientStopRecords -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientStopRecords is missing.'
      }

      $processes = @(
        [pscustomobject]@{ ProcessId = 10612; ParentProcessId = 1; Name = 'ssh.exe'; CommandLine = 'ssh.exe -L 15001:172.18.99.9:8090 -L 15100:172.18.99.6:5100 -L 15002:172.18.99.2:9000 -N ubuntu@42.194.218.158' }
        [pscustomobject]@{ ProcessId = 40000; ParentProcessId = 1; Name = 'ssh.exe'; CommandLine = 'ssh.exe ubuntu@other-host' }
      )

      $rules = Get-WindowsTunnelClientProcessRules -ApiLocalPort 15001 -ImLocalPort 15100 -MinioLocalPort 15002
      $result = Get-WindowsTunnelClientStopRecords -Processes $processes -Rules $rules

      ($result.ProcessId | Sort-Object) -join ',' | Should Be '10612'
    }

    It 'uses the minio container address for the default MinIO tunnel target' {
      if (-not (Get-Command Get-WindowsTunnelClientProcessRules -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientProcessRules is missing.'
      }

      $rules = Get-WindowsTunnelClientProcessRules -ApiLocalPort 15001 -ImLocalPort 15100
      $sshRule = $rules | Where-Object { $_.Name -eq 'ssh.exe' } | Select-Object -First 1

      $sshRule | Should Not BeNullOrEmpty
      ($sshRule.Patterns -contains '-L 15002:172.18.0.2:9000') | Should Be $true
      ($sshRule.Patterns -contains '-L 15002:172.18.0.4:9000') | Should Be $false
    }

    It 'uses the wukongim container address for the default IM tunnel target' {
      if (-not (Get-Command Get-WindowsTunnelClientProcessRules -ErrorAction SilentlyContinue)) {
        throw 'Get-WindowsTunnelClientProcessRules is missing.'
      }

      $rules = Get-WindowsTunnelClientProcessRules -ApiLocalPort 15001 -ImLocalPort 15100
      $sshRule = $rules | Where-Object { $_.Name -eq 'ssh.exe' } | Select-Object -First 1

      $sshRule | Should Not BeNullOrEmpty
      ($sshRule.Patterns -contains '-L 15100:172.18.0.6:5100') | Should Be $true
      ($sshRule.Patterns -contains '-L 15100:127.0.0.1:5100') | Should Be $false
    }

    It 'keeps start and stop script defaults aligned with the reachable tunnel targets' {
      $scriptPaths = @(
        (Join-Path $PSScriptRoot '..\start_windows_tunnel_client.ps1'),
        (Join-Path $PSScriptRoot '..\stop_windows_tunnel_client.ps1')
      )

      foreach ($scriptPath in $scriptPaths) {
        $content = Get-Content -Path $scriptPath -Raw
        $content | Should Match "\[string\]\`$ImRemote = '172\.18\.0\.6:5100'"
        $content | Should Not Match "\[string\]\`$ImRemote = '127\.0\.0\.1:5100'"
        $content | Should Match "\[string\]\`$MinioRemote = '172\.18\.0\.2:9000'"
        $content | Should Not Match "\[string\]\`$MinioRemote = '172\.18\.0\.4:9000'"
      }
    }
  }
}
