param(
    [string]$DotnetPath = $env:DINGTALK_HOST_DOTNET,
    [string]$DingTalkLauncherPath = $env:DINGTALK_HOST_LAUNCHER,
    [int]$RemoteDebuggingPort = 0,
    [string]$Token = $(if ($env:DINGTALK_HOST_TOKEN) { $env:DINGTALK_HOST_TOKEN } else { "local-dev-token" }),
    [int]$StartupTimeoutSeconds = 20,
    [int]$AttachWaitSeconds = 6,
    [int]$UiaSnapshotLimit = 80,
    [int]$UiaCandidateSnapshotLimit = 30,
    [switch]$LaunchDingTalk,
    [switch]$RestartDingTalk,
    [switch]$RestoreDingTalkWindow,
    [switch]$EnableRendererAccessibility,
    [string]$OcrCommand = $env:DINGTALK_HOST_OCR_COMMAND,
    [string]$OcrArguments = $env:DINGTALK_HOST_OCR_ARGUMENTS,
    [string]$OcrEnvironment = $env:DINGTALK_HOST_OCR_ENV
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = Join-Path $root "src\DingTalkWindowsHost.App\DingTalkWindowsHost.App.csproj"
$runtimePath = Join-Path $root "src\DingTalkWindowsHost.App\bin\Debug\net8.0-windows\runtime"
$journalPath = Join-Path $runtimePath "window-attachment.json"
$baseUri = "http://127.0.0.1:17651"
$headers = @{ "X-DingTalk-Host-Token" = $Token }
$runStartedAt = [DateTimeOffset]::UtcNow

if ([string]::IsNullOrWhiteSpace($DotnetPath)) {
    $DotnetPath = "dotnet"
}

function Wait-ForApi {
    param([int]$TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            return Invoke-RestMethod -Uri "$baseUri/status" -Headers $headers -Method Get
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    throw "Loopback API did not become ready within $TimeoutSeconds seconds."
}

function Invoke-HostApi {
    param(
        [string]$Path,
        [string]$Method = "Get"
    )

    try {
        Invoke-RestMethod -Uri "$baseUri$Path" -Headers $headers -Method $Method
    } catch {
        $statusCode = ""
        $responseBody = ""
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = [System.IO.StreamReader]::new($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            } catch {
                $responseBody = "<failed to read response body>"
            }
        }

        throw "Host API request failed: method=$Method path=$Path status=$statusCode body=$responseBody error=$($_.Exception.Message)"
    }
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    return '"' + ($Value -replace '\\(?=\\*")', '$&$&' -replace '"', '\"') + '"'
}

$hostProcess = $null
try {
    Push-Location $root

    & $DotnetPath build $projectPath -c Debug | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Host app build failed."
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $DotnetPath
    $startInfo.Arguments = (@("run", "--project", $projectPath, "-c", "Debug", "--no-build") |
        ForEach-Object { Quote-ProcessArgument $_ }) -join " "
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    if (-not [string]::IsNullOrWhiteSpace($DingTalkLauncherPath)) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_LAUNCHER"] = $DingTalkLauncherPath
    }
    if ($RemoteDebuggingPort -gt 0) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_REMOTE_DEBUGGING_PORT"] = $RemoteDebuggingPort.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($EnableRendererAccessibility) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_ENABLE_RENDERER_ACCESSIBILITY"] = "1"
    }
    if (-not [string]::IsNullOrWhiteSpace($OcrCommand)) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_OCR_COMMAND"] = $OcrCommand
    }
    if (-not [string]::IsNullOrWhiteSpace($OcrArguments)) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_OCR_ARGUMENTS"] = $OcrArguments
    }
    if (-not [string]::IsNullOrWhiteSpace($OcrEnvironment)) {
        $startInfo.EnvironmentVariables["DINGTALK_HOST_OCR_ENV"] = $OcrEnvironment
    }

    $hostProcess = [System.Diagnostics.Process]::Start($startInfo)

    $initialStatus = Wait-ForApi -TimeoutSeconds $StartupTimeoutSeconds
    $launcherDiagnostics = Invoke-HostApi -Path "/diagnostics/launcher"
    $launchResult = $null
    $restartResult = $null
    if ($RestartDingTalk) {
        $restartResult = Invoke-HostApi -Path "/control/restart-dingtalk" -Method "Post"
        Start-Sleep -Seconds 6
    } elseif ($LaunchDingTalk) {
        $launchResult = Invoke-HostApi -Path "/control/launch-dingtalk" -Method "Post"
        Start-Sleep -Seconds 4
    }
    $restoreResult = $null
    if ($RestoreDingTalkWindow) {
        $restoreResult = Invoke-HostApi -Path "/control/restore-dingtalk-window" -Method "Post"
        Start-Sleep -Seconds 2
    }

    $startStatus = Invoke-HostApi -Path "/control/start" -Method "Post"
    Start-Sleep -Seconds $AttachWaitSeconds
    $closeSearchOverlayResult = Invoke-HostApi -Path "/control/close-search-overlay" -Method "Post"
    Start-Sleep -Seconds 1
    $openMessagesResult = Invoke-HostApi -Path "/control/open-messages" -Method "Post"
    Start-Sleep -Seconds 2
    $structuredSources = Invoke-HostApi -Path "/diagnostics/structured-sources"
    $devToolsTargets = Invoke-HostApi -Path "/diagnostics/devtools-targets"
    $localStructuredSources = Invoke-HostApi -Path "/diagnostics/local-structured-sources?limit=30"
    $localStructuredSourceInspection = Invoke-HostApi -Path "/diagnostics/local-structured-source-inspection?limit=12&itemLimit=20"
    $localStructuredContentShape = Invoke-HostApi -Path "/diagnostics/local-structured-content-shape?limit=12&itemLimit=20&sampleLimit=5"
    $conversationDiagnostics = Invoke-HostApi -Path "/diagnostics/conversations?limit=20"
    $attachedStatus = Invoke-HostApi -Path "/status"
    $triggerSnapshots = Invoke-HostApi -Path "/conversation-triggers/recent?limit=10"
    $recentEvents = Invoke-HostApi -Path "/events/recent?limit=100"
    $newRecentEvents = @($recentEvents | Where-Object {
        try {
            [DateTimeOffset]::Parse($_.observedAt).ToUniversalTime() -ge $runStartedAt
        } catch {
            $false
        }
    } | Select-Object -First 10)
    $displayRecentEvents = @($recentEvents | Select-Object -First 10)
    $uiaSnapshot = Invoke-HostApi -Path "/diagnostics/uia-snapshot?limit=$UiaSnapshotLimit"
    $uiaMessageSurface = Invoke-HostApi -Path "/diagnostics/uia-message-surface?limit=240"
    $windowScreenshot = $null
    $windowScreenshotError = ""
    try {
        $windowScreenshotPath = "/diagnostics/screenshot"
        if (-not [string]::IsNullOrWhiteSpace($attachedStatus.currentHwnd)) {
            $windowScreenshotPath = "${windowScreenshotPath}?hwnd=$($attachedStatus.currentHwnd)"
        }
        $windowScreenshot = Invoke-HostApi -Path $windowScreenshotPath -Method "Post"
    } catch {
        $windowScreenshotError = $_.ToString()
    }
    $chatScreenshot = $null
    $chatScreenshotError = ""
    try {
        $chatScreenshotPath = "/diagnostics/chat-screenshot"
        if (-not [string]::IsNullOrWhiteSpace($attachedStatus.currentHwnd)) {
            $chatScreenshotPath = "${chatScreenshotPath}?hwnd=$($attachedStatus.currentHwnd)"
        }
        $chatScreenshot = Invoke-HostApi -Path $chatScreenshotPath -Method "Post"
    } catch {
        $chatScreenshotError = $_.ToString()
    }
    $uiaCandidateDiagnostics = Invoke-HostApi -Path "/diagnostics/uia-candidates?limit=8&snapshotLimit=$UiaCandidateSnapshotLimit&conversationLimit=20"
    $windowState = Invoke-HostApi -Path "/diagnostics/window-state?limit=12"
    $windowCandidates = Invoke-HostApi -Path "/diagnostics/window-candidates?limit=12"
    $stopStatus = Invoke-HostApi -Path "/control/stop" -Method "Post"
    Start-Sleep -Seconds 2
    $journalExistsAfterStop = Test-Path -LiteralPath $journalPath

    [pscustomobject]@{
        initialShellState = $initialStatus.shellState
        startShellState = $startStatus.shellState
        attachedShellState = $attachedStatus.shellState
        attachedHwnd = $attachedStatus.currentHwnd
        ocrEnabled = $attachedStatus.ocrEnabled
        conversationReadiness = $attachedStatus.conversationReadiness
        conversationReadinessMessage = $attachedStatus.conversationReadinessMessage
        conversationCount = @($conversationDiagnostics.conversations).Count
        blockingDialogCount = @($conversationDiagnostics.blockingDialogs).Count
        conversationRecommendation = $conversationDiagnostics.recommendation
        triggerSnapshotCount = @($triggerSnapshots).Count
        recentEventCount = @($recentEvents).Count
        newRecentEventCount = @($newRecentEvents).Count
        newRecentEvents = @($newRecentEvents)
        recentEvents = @($displayRecentEvents)
        uiaSnapshotCount = @($uiaSnapshot).Count
        uiaSnapshot = @($uiaSnapshot)
        uiaMessageSurfaceCount = @($uiaMessageSurface).Count
        uiaMessageSurface = @($uiaMessageSurface)
        windowScreenshotStatus = $(if ($windowScreenshot) { "Captured" } else { "Unavailable" })
        windowScreenshotPath = $(if ($windowScreenshot) { $windowScreenshot.localImagePath } else { "" })
        windowScreenshotSha256 = $(if ($windowScreenshot) { $windowScreenshot.sha256 } else { "" })
        windowScreenshotSize = $(if ($windowScreenshot) { "$($windowScreenshot.width)x$($windowScreenshot.height)" } else { "" })
        windowScreenshotError = $windowScreenshotError
        chatScreenshotStatus = $(if ($chatScreenshot) { "Captured" } else { "Unavailable" })
        chatScreenshotPath = $(if ($chatScreenshot) { $chatScreenshot.localImagePath } else { "" })
        chatScreenshotSha256 = $(if ($chatScreenshot) { $chatScreenshot.sha256 } else { "" })
        chatScreenshotSize = $(if ($chatScreenshot) { "$($chatScreenshot.width)x$($chatScreenshot.height)" } else { "" })
        chatScreenshotError = $chatScreenshotError
        uiaCandidateRecommendation = $uiaCandidateDiagnostics.recommendation
        uiaCandidateProbeCount = @($uiaCandidateDiagnostics.probes).Count
        uiaCandidateProbes = @($uiaCandidateDiagnostics.probes | ForEach-Object {
            [pscustomobject]@{
                hwnd = $_.hwnd
                readiness = $_.readiness
                conversationCount = $_.conversationCount
                blockingDialogCount = $_.blockingDialogCount
                title = $_.title
                className = $_.className
                visible = $_.isVisible
                top = $_.isTopLevel
                hosted = $_.isHosted
                selected = $_.isSelectedWindowCandidate
                size = "$($_.width)x$($_.height)"
                recommendation = $_.recommendation
                error = $_.error
                nodeSummary = @($_.nodeSummary)
            }
        })
        launcherReadiness = $launcherDiagnostics.readiness
        launcherConfigured = $launcherDiagnostics.isConfigured
        launcherPathExists = $launcherDiagnostics.pathExists
        launcherRemoteDebuggingPort = $launcherDiagnostics.remoteDebuggingPort
        launcherRendererAccessibilityEnabled = $launcherDiagnostics.rendererAccessibilityEnabled
        launcherRecommendation = $launcherDiagnostics.recommendation
        launchRequested = [bool]$LaunchDingTalk
        launchStatus = $(if ($launchResult) { $launchResult.status } else { "" })
        launchMessage = $(if ($launchResult) { $launchResult.message } else { "" })
        restartRequested = [bool]$RestartDingTalk
        restartStatus = $(if ($restartResult) { $restartResult.status } else { "" })
        restartMessage = $(if ($restartResult) { $restartResult.message } else { "" })
        restoreRequested = [bool]$RestoreDingTalkWindow
        restoreStatus = $(if ($restoreResult) { $restoreResult.status } else { "" })
        restoreTargetHwnd = $(if ($restoreResult) { $restoreResult.targetHwnd } else { "" })
        restoreMessage = $(if ($restoreResult) { $restoreResult.message } else { "" })
        closeSearchOverlayStatus = $closeSearchOverlayResult.status
        closeSearchOverlayTargetHwnd = $closeSearchOverlayResult.targetHwnd
        closeSearchOverlayMessage = $closeSearchOverlayResult.message
        openMessagesStatus = $openMessagesResult.status
        openMessagesTargetHwnd = $openMessagesResult.targetHwnd
        openMessagesMessage = $openMessagesResult.message
        structuredSourceRecommendation = $structuredSources.recommendation
        structuredSourceSignals = @($structuredSources.signals | ForEach-Object {
            [pscustomobject]@{
                kind = $_.kind
                status = $_.status
                latencyMs = $_.estimatedLatencyMs
                evidence = $_.evidence
                nextAction = $_.nextAction
            }
        })
        devToolsTargetStatus = $devToolsTargets.status
        devToolsTargetPort = $devToolsTargets.port
        devToolsTargetOwnerProcessId = $devToolsTargets.ownerProcessId
        devToolsTargetRecommendation = $devToolsTargets.recommendation
        devToolsTargets = @($devToolsTargets.targets | ForEach-Object {
            [pscustomobject]@{
                id = $_.id
                type = $_.type
                title = $_.title
                url = $_.url
                hasWebSocketDebuggerUrl = $_.hasWebSocketDebuggerUrl
            }
        })
        localStructuredSourceStatus = $localStructuredSources.status
        localStructuredSourceCandidateCount = $localStructuredSources.candidateCount
        localStructuredSourceRecommendation = $localStructuredSources.recommendation
        localStructuredSourceCandidates = @($localStructuredSources.candidates | Select-Object -First 12 | ForEach-Object {
            [pscustomobject]@{
                kind = $_.kind
                pathHint = $_.pathHint
                sizeBytes = $_.sizeBytes
                lastWriteTime = $_.lastWriteTime
                evidence = $_.evidence
            }
        })
        localStructuredSourceInspectionStatus = $localStructuredSourceInspection.status
        localStructuredSourceInspectedCount = $localStructuredSourceInspection.inspectedCount
        localStructuredSourceInspectionRecommendation = $localStructuredSourceInspection.recommendation
        localStructuredSourceInspections = @($localStructuredSourceInspection.inspections | Select-Object -First 8 | ForEach-Object {
            [pscustomobject]@{
                kind = $_.kind
                status = $_.status
                pathHint = $_.pathHint
                evidence = $_.evidence
                structureItems = @($_.structureItems | Select-Object -First 8 | ForEach-Object {
                    [pscustomobject]@{
                        kind = $_.kind
                        name = $_.name
                        childNames = @($_.childNames)
                        evidence = $_.evidence
                    }
                })
            }
        })
        localStructuredContentShapeStatus = $localStructuredContentShape.status
        localStructuredContentShapeCount = $localStructuredContentShape.shapeCount
        localStructuredContentShapeRecommendation = $localStructuredContentShape.recommendation
        localStructuredContentShapes = @($localStructuredContentShape.shapes | Select-Object -First 8 | ForEach-Object {
            [pscustomobject]@{
                kind = $_.kind
                status = $_.status
                pathHint = $_.pathHint
                evidence = $_.evidence
                keywordHits = @($_.keywordHits | Select-Object -First 12)
                tables = @($_.tables | Select-Object -First 6 | ForEach-Object {
                    [pscustomobject]@{
                        name = $_.name
                        rowCount = $_.rowCount
                        score = $_.score
                        evidence = $_.evidence
                        fields = @($_.fields | Select-Object -First 12 | ForEach-Object {
                            [pscustomobject]@{
                                name = $_.name
                                role = $_.role
                                nonEmptySampleCount = $_.nonEmptySampleCount
                                minLength = $_.minLength
                                maxLength = $_.maxLength
                                sampleValueHashes = @($_.sampleValueHashes)
                            }
                        })
                    }
                })
            }
        })
        windowHealth = $windowState.health
        windowRecommendation = $windowState.recommendation
        windowSelectedHwnd = $windowState.selectedHwnd
        windowVisibleCandidates = $windowState.visibleCandidates
        windowHiddenWorkspaceCandidates = $windowState.hiddenWorkspaceCandidates
        windowBlockingDialogCandidates = $windowState.blockingDialogCandidates
        windowRejectionReasonCounts = $windowState.rejectionReasonCounts
        windowCandidateDecisions = @($windowState.candidates | Select-Object -First 8 | ForEach-Object {
            [pscustomobject]@{
                hwnd = $_.hwnd
                decision = $_.decision
                rejectionReason = $_.rejectionReason
                title = $_.title
                className = $_.className
                visible = $_.isVisible
                enabled = $_.isEnabled
                top = $_.isTopLevel
                tool = $_.isToolWindow
                size = "$($_.width)x$($_.height)"
            }
        })
        windowCandidateSummary = @($windowCandidates)
        stopShellState = $stopStatus.shellState
        journalExistsAfterStop = $journalExistsAfterStop
        journalPath = $journalPath
    } | ConvertTo-Json -Depth 6

    if ($journalExistsAfterStop) {
        throw "Attachment journal still exists after /control/stop: $journalPath"
    }
} finally {
    Pop-Location
    if ($hostProcess -and -not $hostProcess.HasExited) {
        $hostProcess.CloseMainWindow() | Out-Null
        if (-not $hostProcess.WaitForExit(5000)) {
            Stop-Process -Id $hostProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
