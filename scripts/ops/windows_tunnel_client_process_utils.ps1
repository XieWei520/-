$ErrorActionPreference = 'Stop'

function Test-CommandLineMatchesAnyPattern {
  param(
    [AllowNull()]
    [string]$CommandLine,
    [string[]]$Patterns
  )

  if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    return $false
  }

  foreach ($pattern in @($Patterns)) {
    if (-not [string]::IsNullOrWhiteSpace($pattern) -and $CommandLine -like "*$pattern*") {
      return $true
    }
  }

  return $false
}

function Test-WindowsTunnelIPv4Address {
  param([AllowNull()][string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }

  $octets = $Value.Trim().Split('.')
  if ($octets.Count -ne 4) {
    return $false
  }

  foreach ($octet in $octets) {
    if ($octet -notmatch '^\d{1,3}$') {
      return $false
    }

    $number = [int]$octet
    if ($number -lt 0 -or $number -gt 255) {
      return $false
    }
  }

  return $true
}

function Resolve-WindowsTunnelRemoteTarget {
  param(
    [Parameter(Mandatory = $true)]
    [string]$DefaultRemote,
    [Parameter(Mandatory = $true)]
    [string]$ContainerName,
    [Parameter(Mandatory = $true)]
    [int]$ContainerPort,
    [Parameter(Mandatory = $true)]
    [scriptblock]$ContainerIpResolver
  )

  $resolvedOutput = @(& $ContainerIpResolver $ContainerName)
  $resolvedIp = @(
    $resolvedOutput |
      ForEach-Object { "$_".Trim() } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  ) | Select-Object -First 1

  if (-not (Test-WindowsTunnelIPv4Address -Value $resolvedIp)) {
    throw "Unable to resolve $ContainerName for $DefaultRemote; resolver returned '$resolvedIp'."
  }

  return "${resolvedIp}:$ContainerPort"
}

function Get-WindowsTunnelClientProcessRules {
  param(
    [string]$ApiRemote = '172.18.0.9:8090',
    [string]$ImRemote = '172.18.0.6:5100',
    [string]$MinioRemote = '172.18.0.2:9000',
    [int]$ApiLocalPort = 15001,
    [int]$ImLocalPort = 15100,
    [int]$MinioLocalPort = 15002
  )

  @(
    [pscustomobject]@{
      Name = 'ssh.exe'
      Patterns = @(
        "-L ${ApiLocalPort}:",
        "-L ${ImLocalPort}:",
        "-L ${MinioLocalPort}:",
        "-L ${ApiLocalPort}:$ApiRemote",
        "-L ${ImLocalPort}:$ImRemote",
        "-L ${MinioLocalPort}:$MinioRemote"
      )
    }
    [pscustomobject]@{
      Name = 'powershell.exe'
      Patterns = @(
        'windows_client.tunnel',
        "--dart-define=WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "--dart-define=WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "--dart-define=WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort",
        "--dart-define=WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort"
      )
    }
    [pscustomobject]@{
      Name = 'cmd.exe'
      Patterns = @(
        'wukong_tcp_probe',
        'windows_client.tunnel',
        "WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort",
        "WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort"
      )
    }
    [pscustomobject]@{
      Name = 'dart.exe'
      Patterns = @(
        'wukong_tcp_probe',
        'windows_client.tunnel',
        "WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort",
        "WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort"
      )
    }
    [pscustomobject]@{
      Name = 'dartvm.exe'
      Patterns = @(
        'wukong_tcp_probe',
        'windows_client.tunnel',
        "WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort",
        "WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort"
      )
    }
    [pscustomobject]@{
      Name = 'dartaotruntime.exe'
      Patterns = @(
        'windows_client.tunnel',
        "WK_DEV_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_PROD_BASE_URL=http://127.0.0.1:$ApiLocalPort",
        "WK_DEV_WS_ADDR=127.0.0.1:$ImLocalPort",
        "WK_PROD_WS_ADDR=127.0.0.1:$ImLocalPort"
      )
    }
    [pscustomobject]@{
      Name = 'InfoEquity.exe'
      Patterns = @()
    }
    [pscustomobject]@{
      Name = 'wukong_im_app.exe'
      Patterns = @()
    }
  )
}

function Select-ProcessRecordsByRules {
  param(
    [object[]]$Processes,
    [object[]]$Rules
  )

  $matched = @()

  foreach ($process in @($Processes)) {
    foreach ($rule in @($Rules)) {
      if ($process.Name -ne $rule.Name) {
        continue
      }

      $patterns = @($rule.Patterns)
      if ($patterns.Count -eq 0) {
        $matched += $process
        break
      }

      if (Test-CommandLineMatchesAnyPattern -CommandLine $process.CommandLine -Patterns $patterns) {
        $matched += $process
        break
      }
    }
  }

  $matched | Sort-Object ProcessId -Unique
}

function Get-DescendantProcessIds {
  param(
    [object[]]$Processes,
    [int[]]$ParentIds
  )

  $allProcesses = @($Processes)
  $queue = New-Object System.Collections.Queue
  $seen = @{}
  $descendants = New-Object System.Collections.Generic.List[int]

  foreach ($parentId in @($ParentIds | Sort-Object -Unique)) {
    [void]$queue.Enqueue([int]$parentId)
  }

  while ($queue.Count -gt 0) {
    $currentParentId = [int]$queue.Dequeue()

    foreach ($process in $allProcesses) {
      if ([int]$process.ParentProcessId -ne $currentParentId) {
        continue
      }

      $childId = [int]$process.ProcessId
      if ($seen.ContainsKey($childId)) {
        continue
      }

      $seen[$childId] = $true
      $descendants.Add($childId) | Out-Null
      [void]$queue.Enqueue($childId)
    }
  }

  $descendants.ToArray()
}

function Get-WindowsTunnelClientStopRecords {
  param(
    [object[]]$Processes,
    [object[]]$Rules
  )

  $allProcesses = @($Processes)
  $rootMatches = @(Select-ProcessRecordsByRules -Processes $allProcesses -Rules $Rules)
  if ($rootMatches.Count -eq 0) {
    return @()
  }

  $targetIds = @{}

  foreach ($process in $rootMatches) {
    $targetIds[[int]$process.ProcessId] = $true
  }

  foreach ($descendantId in @(Get-DescendantProcessIds -Processes $allProcesses -ParentIds $rootMatches.ProcessId)) {
    $targetIds[[int]$descendantId] = $true
  }

  $allProcesses |
    Where-Object { $targetIds.ContainsKey([int]$_.ProcessId) } |
    Sort-Object ProcessId -Unique
}

function Get-LiveProcessRecords {
  Get-CimInstance Win32_Process |
    Select-Object ProcessId, ParentProcessId, Name, CommandLine
}

function Stop-ProcessRecords {
  param(
    [object[]]$Processes
  )

  $targets = @($Processes | Sort-Object ProcessId -Descending -Unique)
  foreach ($process in $targets) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
  }

  $targets
}

function Stop-WindowsTunnelClientProcesses {
  param(
    [string]$ApiRemote = '172.18.0.9:8090',
    [string]$ImRemote = '172.18.0.6:5100',
    [string]$MinioRemote = '172.18.0.2:9000',
    [int]$ApiLocalPort = 15001,
    [int]$ImLocalPort = 15100,
    [int]$MinioLocalPort = 15002
  )

  $rules = Get-WindowsTunnelClientProcessRules `
    -ApiRemote $ApiRemote `
    -ImRemote $ImRemote `
    -MinioRemote $MinioRemote `
    -ApiLocalPort $ApiLocalPort `
    -ImLocalPort $ImLocalPort `
    -MinioLocalPort $MinioLocalPort

  $liveProcesses = @(Get-LiveProcessRecords)
  $targets = @(Get-WindowsTunnelClientStopRecords -Processes $liveProcesses -Rules $rules)

  Stop-ProcessRecords -Processes $targets
}
