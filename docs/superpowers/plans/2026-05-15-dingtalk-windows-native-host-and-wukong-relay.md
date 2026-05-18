# DingTalk Windows Native Host And WuKong Relay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Windows-native DingTalk host PoC that embeds the installed DingTalk desktop window, captures message events locally with structured sources before OCR, and exposes a stable loopback contract that WuKong IM can later use to relay matched events into WuKong groups.

**Architecture:** Keep all Windows-native behavior in a new `.NET 8 + WPF` solution under `tools/dingtalk_windows_host/`. The host owns window embedding, structured-source diagnostics, UIA probing, screenshot/image fallback, SQLite persistence, and loopback APIs. WuKong IM remains a separate process and later consumes the host's JSON contract to provide routing, logs, and final message delivery through the existing `ApiChatSceneGateway.sendMessageContent(...)` path.

**Tech Stack:** `.NET 8`, `WPF`, `FlaUI.UIA3`, `Microsoft.Data.Sqlite`, `Serilog`, `ImageSharp`, ASP.NET Core minimal API, Flutter/Dart for the later WuKong-side relay page

---

## File Structure

### New Windows-native host solution

- `tools/dingtalk_windows_host/DingTalkWindowsHost.sln`
  - Solution root for the native PoC
- `tools/dingtalk_windows_host/Directory.Build.props`
  - Shared target framework, nullable, warnings-as-errors, package version policy
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/`
  - Shared event contracts, status contracts, loopback DTOs, and enums
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/`
  - WPF shell window, host panel, view models, startup wiring, operator controls
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/`
  - HWND discovery, window attach/detach, UIA selectors, text extraction, image fallback actions
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/`
  - SQLite initialization, repositories, dedupe helpers, retention cleanup
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/`
  - Loopback HTTP endpoints and API-to-repository mapping
- `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/`
  - Contract, normalization, repository, and API tests

### Future WuKong-side integration

- `lib/modules/dingtalk_monitor/`
  - Recreated only after the native host contract is stable; mirrors the Feishu monitor shape but does not host or automate DingTalk itself
- `test/modules/dingtalk_monitor/`
  - Route matching, shell client, runner, and UI tests for the future WuKong-side control plane
- `lib/modules/local_monitor/`
  - Existing relay abstractions reused by the WuKong-side DingTalk integration
- `lib/modules/feishu_monitor/`
  - Reference behavior for route matching, dedupe, and relay identity handling

## Dependency Order

1. Contracts and solution bootstrap
2. WPF shell and HWND hosting
3. Structured-source diagnostics and low-latency source ranking
4. UIA text capture and trigger path
5. SQLite storage and loopback API
6. M1 runtime verification
7. Image fallback and screenshot persistence
8. Optional OCR fallback and noise filtering
9. WuKong-side DingTalk shell client and route UI
10. WuKong-side auto-forward runner and send path

## Task List

### Task 1: Bootstrap The Native Host Solution

**Files:**
- Create: `tools/dingtalk_windows_host/DingTalkWindowsHost.sln`
- Create: `tools/dingtalk_windows_host/Directory.Build.props`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/DingTalkWindowsHost.Contracts.csproj`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/DingTalkWindowsHost.App.csproj`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/DingTalkWindowsHost.Automation.csproj`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/DingTalkWindowsHost.Storage.csproj`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/DingTalkWindowsHost.Api.csproj`
- Create: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj`

- [ ] Create the solution and project graph with references:
  - `App -> Contracts, Automation, Storage, Api`
  - `Automation -> Contracts`
  - `Storage -> Contracts`
  - `Api -> Contracts, Storage`
  - `Tests -> Contracts, Automation, Storage, Api`
- [ ] Put the shared build policy in `Directory.Build.props`:
  ```xml
  <Project>
    <PropertyGroup>
      <TargetFramework>net8.0-windows</TargetFramework>
      <Nullable>enable</Nullable>
      <ImplicitUsings>enable</ImplicitUsings>
      <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
      <LangVersion>latest</LangVersion>
    </PropertyGroup>
  </Project>
  ```
- [ ] Define the first shared contracts in `HostContracts.cs`:
  ```csharp
  public enum CaptureSource
  {
      UiaText,
      UiaImageMetadata,
      PreviewSave,
      ChatAreaScreenshot,
      ChatAreaScreenshotOcr
  }

  public sealed record DingTalkObservedEvent(
      string EventId,
      string SourceConversationId,
      string SourceConversationName,
      string EmbeddedSourceName,
      string SenderName,
      DateTimeOffset ObservedAt,
      string Text,
      string LocalImagePath,
      CaptureSource CaptureSource,
      string ContentHash);
  ```
- [ ] Add a smoke test that compiles the contract round-trip:
  ```csharp
  [Fact]
  public void ObservedEvent_CanBeConstructed()
  {
      var evt = new DingTalkObservedEvent(
          "evt-1", "chat-1", "Alpha", "", "Alice",
          DateTimeOffset.Parse("2026-05-15T10:00:00Z"),
          "hello", "", CaptureSource.UiaText, "hash-1");
      evt.SourceConversationName.Should().Be("Alpha");
  }
  ```
- [ ] Run:
  - `dotnet restore tools/dingtalk_windows_host/DingTalkWindowsHost.sln`
  - `dotnet build tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
  - `dotnet test tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`

### Task 2: Build The WPF Host Shell And HWND Container

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/App.xaml`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/App.xaml.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/DingTalkWindowLocator.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/NativeWindowEmbedder.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/WindowSupervisor.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/WindowHostTests.cs`

- [ ] Add a failing test for the window locator selection rules:
  ```csharp
  [Fact]
  public void Locator_PrefersMainVisibleWindow()
  {
      var locator = new DingTalkWindowLocator();
      var hwnd = locator.ChooseMainWindow(new[]
      {
          new WindowCandidate((IntPtr)1, "DingTalk", true, true),
          new WindowCandidate((IntPtr)2, "Upgrade", true, false),
      });
      hwnd.Should().Be((IntPtr)1);
  }
  ```
- [ ] Implement the host window with:
  - left control column: start, stop, reload, reattach, status
  - right content panel: fixed-size hosted DingTalk window surface
  - bottom diagnostics strip: shell state, current HWND, last event time
- [ ] Implement `NativeWindowEmbedder` around `SetParent`, `MoveWindow`, `SetWindowPos`, and size locking:
  ```csharp
  public void Attach(IntPtr childHwnd, IntPtr hostPanelHwnd, RECT bounds)
  {
      SetParent(childHwnd, hostPanelHwnd);
      MoveWindow(childHwnd, 0, 0, bounds.Width, bounds.Height, true);
      SetWindowPos(childHwnd, HWND_TOP, 0, 0, bounds.Width, bounds.Height, SWP_SHOWWINDOW);
  }
  ```
- [ ] Add a supervisor loop that can:
  - relaunch DingTalk if not found
  - reattach if HWND changes
  - keep fixed size and top-level parent relationship
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter WindowHost`
  - `dotnet run --project tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/DingTalkWindowsHost.App.csproj`

### Task 3: Implement M1 UIA Text Capture

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/UiaChatSurfaceProbe.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/UiaMessageExtractor.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/EventNormalizer.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/UiaMessageExtractorTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/EventNormalizerTests.cs`

- [ ] Add a failing extractor test using fixture-like node snapshots:
  ```csharp
  [Fact]
  public void Extractor_MapsLatestTextMessage()
  {
      var nodes = new[]
      {
          new UiaNode("群名称", "Alpha Group", "Text"),
          new UiaNode("发送人", "Alice", "Text"),
          new UiaNode("消息正文", "hello from dingtalk", "Text"),
      };
      var result = new UiaMessageExtractor().ExtractLatest(nodes);
      result!.SenderName.Should().Be("Alice");
      result.Text.Should().Be("hello from dingtalk");
  }
  ```
- [ ] Implement selector rules in order:
  - explicit automation IDs when present
  - control type and label heuristics
  - bounded tree traversal under the visible chat container
- [ ] Normalize the capture into `DingTalkObservedEvent` with:
  - stable `EventId`
  - normalized conversation name
  - optional embedded source marker if the body contains `[群名]`
  - `CaptureSource.UiaText`
  - `ContentHash = sha256(normalizedText)`
- [ ] Add a polling loop in the app that probes the active chat surface every 2 seconds while capture is enabled
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter UiaMessageExtractor`
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter EventNormalizer`

### Task 3A: Add Structured Source Diagnostics Before OCR

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/StructuredSources/StructuredSourceProbe.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/StructuredSources/DingTalkProcessCandidate.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IStructuredSourceProbe.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceProbeTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [x] Add a structured source probe result that ranks:
  - UI Automation
  - embedded Chromium windows
  - browser DevTools candidates
  - passive network/event candidates
  - local cache/log candidates that require manual approval
  - screenshot OCR as fallback-only
- [x] Expose `GET /diagnostics/structured-sources` behind the same local token as other loopback endpoints.
- [x] Keep the default recommendation focused on DevTools/DOM/network/UIA before enabling OCR.
- [x] Do not read DingTalk credentials, cookies, local databases, or local cache/log files in this diagnostic step.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "StructuredSourceProbe|DiagnosticsStructuredSources"`

### Task 3B: Probe Feishu-Like Low-Latency Candidates At Runtime

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/StructuredSources/StructuredSourceProbe.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceProbeTests.cs`

- [x] Parse redacted process command-line metadata when provided by a safe source, including `--remote-debugging-port`, without logging secrets.
- [x] Inspect local loopback ports for DevTools-style endpoints without fetching page contents or credentials.
- [x] Verify loopback DevTools port ownership through Windows TCP listener owning PID before treating it as a DingTalk candidate.
- [x] Probe only `/json/version` metadata on candidate DevTools ports; do not fetch `/json/list`, page targets, cookies, storage, or DOM content in this step.
- [x] Report the runtime recommendation in the loopback API.
- [ ] Report the runtime recommendation in the operator UI.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter StructuredSourceProbe`

### Task 3C: Add UIA Conversation List And Blocking Dialog Diagnostics

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/UiaConversationDiagnosticsExtractor.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/UiaConversationDiagnosticsProvider.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/UiaChatSurfaceProbe.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IUiaConversationDiagnosticsProvider.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/UiaConversationDiagnosticsTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [x] Extract visible conversation list items from `ConvListView`/`ConvListItemListView` UIA nodes.
- [x] Flag unread hints from accessible conversation names.
- [x] Detect blocking dialogs such as `MsgBox`/restart prompts.
- [x] Expose `GET /diagnostics/conversations` behind the local token.
- [x] Keep this as trigger/diagnostics only; do not claim chat body capture from UIA.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "UiaConversationDiagnostics|DiagnosticsConversations"`

### Task 3D: Surface Conversation Diagnostics In The Operator UI

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/StructuredSourceDisplayFormatter.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceDisplayFormatterTests.cs`

- [x] Format conversation diagnostics for the left operator sidebar.
- [x] Show blocking-dialog count and the first visible dialog message.
- [x] Show conversation count and up to five visible conversation names with selected/unread hints.
- [x] Refresh the UI diagnostics on the same low-frequency timer as structured-source status.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter StructuredSourceDisplayFormatter`

### Task 3E: Persist Low-Latency Conversation Trigger Snapshots

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/HostRuntimeStatus.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackStatusDto.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Db/Schema.sql`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Repositories/ConversationTriggerSnapshotsRepository.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/HostRuntimeStatusTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/ConversationTriggerSnapshotsRepositoryTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [ ] Add operator-facing conversation readiness states: `Ready`, `BlockedByDialog`, `NoConversationList`, `ConversationListVisible`.
- [ ] Derive readiness from UIA conversation diagnostics without treating conversation-list data as chat-body capture.
- [ ] Persist conversation-list trigger snapshots when visible conversation/unread/selection state changes.
- [ ] Deduplicate unchanged trigger snapshots by stable content hash so polling does not multiply rows.
- [ ] Expose recent trigger snapshots through the loopback API behind the same local token.
- [ ] Do not forward trigger snapshots and do not enable OCR in this task.
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
  - `dotnet build tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/DingTalkWindowsHost.App.csproj -c Debug`

### Task 3F: Add Typed Window Candidate Health Diagnostics

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IWindowDiagnosticsProvider.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/WindowDiagnosticsProvider.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/StructuredSourceDisplayFormatter.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml`
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/WindowHostTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceDisplayFormatterTests.cs`

- [x] Add `WindowCandidateHealth` states: `Ready`, `NoDingTalkProcess`, `NoEligibleWindow`, `HiddenWorkspaceOnly`, `BlockedByDialog`, `HostedCandidate`.
- [x] Expose typed counts and recommendation text through `GET /diagnostics/window-state`.
- [x] Keep `/diagnostics/window-candidates` as the raw summary endpoint for manual troubleshooting.
- [x] Surface window health in the WPF operator sidebar.
- [x] Add lifecycle script output for `windowHealth`, selected HWND, counts, and recommendation.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "WindowDiagnostics|DiagnosticsWindowState|FormatWindowDiagnostics"`

### Task 3G: Explain Per-Candidate Window Attach Decisions

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/WindowDiagnosticsProvider.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/StructuredSourceDisplayFormatter.cs`
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Update: `tools/dingtalk_windows_host/README.md`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/WindowHostTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceDisplayFormatterTests.cs`

- [x] Add stable candidate decision contracts: `Selected`, `Candidate`, `Rejected`.
- [x] Add stable rejection reasons: `ZeroHandle`, `Disabled`, `ToolWindow`, `NotTopLevel`, `Hidden`, `TooSmall`, `UnsupportedClass`.
- [x] Include per-candidate decisions in `/diagnostics/window-state` without requiring clients to parse raw strings.
- [x] Show the first candidate decisions and rejection-reason counts in the WPF operator sidebar and lifecycle script output.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "WindowDiagnostics|DiagnosticsWindowState|FormatWindowDiagnostics"`

### Task 3H: Add Explicit DingTalk Launcher Recovery Action

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IDingTalkLauncher.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/DingTalkLauncher.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackApiHost.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/HostCompositionRoot.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkLauncherTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [x] Add a launcher service configured by `DINGTALK_HOST_LAUNCHER`.
- [x] Expose explicit `POST /control/launch-dingtalk`; do not auto-restart DingTalk from diagnostics or supervisor loops.
- [x] Add a WPF operator button and visible launcher status.
- [x] Return stable launch statuses: `Started`, `NotConfigured`, `NotFound`, `Failed`.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "DingTalkLauncher|ControlLaunchDingTalk"`

### Task 3I: Add DingTalk Launcher Readiness Diagnostics

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IDingTalkLauncher.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/DingTalkLauncher.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/StructuredSourceDisplayFormatter.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkLauncherTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/StructuredSourceDisplayFormatterTests.cs`

- [x] Expose `GET /diagnostics/launcher` behind the local token.
- [x] Report launcher readiness as `Ready`, `NotConfigured`, or `NotFound`.
- [x] Surface launcher diagnostics in the WPF sidebar and lifecycle script without launching DingTalk.
- [x] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter "DingTalkLauncher|DiagnosticsLauncher|FormatLauncherDiagnostics"`

### Task 3J: Allow Lifecycle Script To Inject Launcher Path

**Files:**
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Update: `tools/dingtalk_windows_host/README.md`

- [x] Add `-DingTalkLauncherPath` to the lifecycle script.
- [x] Pass the launcher path into the host process as `DINGTALK_HOST_LAUNCHER`.
- [x] Keep lifecycle verification non-destructive: report launcher readiness but do not call `/control/launch-dingtalk`.

### Task 3K: Add Explicit Launcher Invocation To Lifecycle Verification

**Files:**
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Update: `tools/dingtalk_windows_host/README.md`

- [x] Add a `-LaunchDingTalk` switch to the lifecycle script.
- [x] Call `/control/launch-dingtalk` only when the switch is present.
- [x] Report `launchRequested`, `launchStatus`, and `launchMessage` in lifecycle JSON output.

### Task 3L: Add Explicit DingTalk Window Restore Recovery

**Files:**
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Models/HostContracts.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Contracts/Services/IDingTalkWindowRestorer.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/WindowHost/DingTalkWindowRestorer.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackApiHost.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/ViewModels/MainWindowViewModel.cs`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/MainWindow.xaml`
- Update: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/HostCompositionRoot.cs`
- Update: `tools/dingtalk_windows_host/Verify-HostLifecycle.ps1`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowRestorerTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [x] Add explicit `POST /control/restore-dingtalk-window`.
- [x] Prefer non-tool DingTalk candidates for restore and avoid restoring tool windows.
- [x] Use `ShowWindow` and `SetForegroundWindow` only when explicitly requested.
- [x] Add WPF and lifecycle-script controls for explicit restore.

### Task 4: Add SQLite Persistence And Loopback API

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Db/SqliteDatabase.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Db/Schema.sql`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Repositories/RawEventsRepository.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Repositories/ForwardJobsRepository.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Repositories/DeliveryLogsRepository.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackApiHost.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/LoopbackEndpoints.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/RawEventsRepositoryTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LoopbackApiTests.cs`

- [ ] Initialize the schema with exactly these core tables:
  ```sql
  CREATE TABLE IF NOT EXISTS raw_events (
    event_id TEXT PRIMARY KEY,
    source_conversation_id TEXT NOT NULL,
    source_conversation_name TEXT NOT NULL,
    embedded_source_name TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    observed_at TEXT NOT NULL,
    text TEXT NOT NULL,
    local_image_path TEXT NOT NULL,
    capture_source TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    dedupe_key TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS forward_jobs (
    job_id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL,
    status TEXT NOT NULL,
    attempts INTEGER NOT NULL,
    last_error TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS delivery_logs (
    log_id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL,
    outcome TEXT NOT NULL,
    detail TEXT NOT NULL,
    created_at TEXT NOT NULL
  );
  ```
- [ ] Add failing repository tests that prove dedupe overwrite semantics:
  ```csharp
  [Fact]
  public async Task RawEventsRepository_Upsert_ReplacesDuplicateEventId()
  {
      await repo.UpsertAsync(first, ct);
      await repo.UpsertAsync(updated, ct);
      var recent = await repo.ListRecentAsync(10, ct);
      recent.Should().ContainSingle().Which.Text.Should().Be("updated");
  }
  ```
- [ ] Expose loopback endpoints:
  - `GET /status`
  - `GET /events/recent?limit=50`
  - `POST /control/start`
  - `POST /control/stop`
  - `POST /control/reload`
- [ ] Bind only to `127.0.0.1` and include a simple install-local token header check
- [ ] Wire capture loop -> repository upsert -> status endpoint
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter RawEventsRepository`
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter LoopbackApi`

### Checkpoint: M1 Complete

- [x] Manually launch the host app and attach the installed DingTalk window
- [x] Confirm the hosted window can be detached through `/control/stop`
- [x] Confirm UIA diagnostics can return node summaries without crashing on unsupported UIA properties
- [x] Confirm screenshot fallback can persist a hosted-window PNG with sha256-based file naming
- [ ] Confirm one latest visible text message lands in `raw_events`
- [ ] Confirm `GET /events/recent` returns that message as JSON
- [ ] Save one screenshot of the M1 shell and note the fixed resolution used for later regression checks

Current M1 runtime note, May 15, 2026:
- `POST /control/start` reached `shellState=Attached` against the installed DingTalk session.
- The selected fallback HWND was `StandardFrame_DingTalk` (`0x390A22` during verification) because the current DingTalk build exposed chat Chromium child windows as mostly empty UIA panes.
- `GET /diagnostics/uia-snapshot` returned navigation/sidebar UIA nodes but did not expose chat message text from the tested session.
- `POST /diagnostics/screenshot` successfully wrote a deduped PNG under `runtime/captures/YYYYMMDD/`.
- Therefore, text capture should proceed through screenshot/OCR fallback unless a later DingTalk build exposes richer UIA nodes.

### Task 5: Implement M2 Image Capture And Fallback

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/ImageMessageDetector.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/ChatAreaScreenshotService.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/PreviewSaveAction.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/Files/CaptureFileStore.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/ImageMessageDetectorTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/ChatAreaScreenshotServiceTests.cs`

- [ ] Add a failing detector test for image placeholder nodes:
  ```csharp
  [Fact]
  public void Detector_RecognizesImagePlaceholderNode()
  {
      var node = new UiaNode("消息正文", "[图片]", "Image");
      new ImageMessageDetector().IsImageMessage(node).Should().BeTrue();
  }
  ```
- [ ] Implement the fallback order:
  1. use UIA metadata if the node yields a reliable image placeholder with local coordinates
  2. trigger preview/save when a dedicated thumbnail click target is available
  3. fall back to chat-area screenshot cropping when preview/save is not safe
- [ ] Persist screenshots under:
  - `tools/dingtalk_windows_host/runtime/captures/YYYYMMDD/`
- [ ] Add `sha256`-based filename reuse so identical fallback images do not multiply on disk
- [ ] Extend normalized events to carry `LocalImagePath` and `CaptureSource.ChatAreaScreenshot` or `CaptureSource.PreviewSave`
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter ImageMessageDetector`
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter ChatAreaScreenshotService`

### Task 6: Implement M2 OCR Fallback And Noise Filtering

**Files:**
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Ocr/LocalOcrService.cs`
- Create: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Ocr/OcrNoiseFilter.cs`
- Modify: `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/Capture/EventNormalizer.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/OcrNoiseFilterTests.cs`
- Test: `tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/LocalOcrServiceTests.cs`

- [x] Add a failing OCR filter test that drops pure timestamp/noise captures:
  ```csharp
  [Theory]
  [InlineData("10:42")]
  [InlineData("昨天")]
  [InlineData("加载中...")]
  public void NoiseFilter_DropsNonMessageText(string input)
  {
      OcrNoiseFilter.IsForwardable(input).Should().BeFalse();
  }
  ```
- [x] Implement OCR as a local-only service abstraction; keep the first version behind an interface so the host can ship M1 without OCR enabled
- [x] Normalize OCR-derived events as `CaptureSource.ChatAreaScreenshotOcr`
- [ ] Reuse the spec dedupe recommendation:
  - `source_chat + sender + timestamp_bucket + content_hash`
- [ ] Store OCR confidence metadata in the event detail payload if available, but do not let low confidence bypass filtering
- [ ] Run:
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter OcrNoiseFilter`
  - `dotnet test tools/dingtalk_windows_host/tests/DingTalkWindowsHost.Tests/DingTalkWindowsHost.Tests.csproj -c Debug --filter LocalOcrService`

### Checkpoint: M2 Complete

- [ ] Capture one visible DingTalk image event and confirm a local screenshot or preview-save file is stored
- [ ] Capture one OCR fallback event and confirm it appears in `raw_events` with `ChatAreaScreenshotOcr`
- [ ] Confirm repeated polling does not create duplicate `raw_events` rows for the same image/text
- [ ] Review the runtime capture directory size and confirm retention policy requirements are still acceptable for PoC use

Current OCR fallback note, May 15, 2026:
- A local `IOcrService` abstraction, disabled `NullOcrService`, `OcrNoiseFilter`, and `ScreenshotOcrCapturePipeline` are implemented.
- The default app wiring keeps OCR disabled, so the host will not create screenshot-derived `raw_events` until a real local OCR engine is injected.
- Unit coverage verifies enabled fake OCR can normalize `ChatAreaScreenshotOcr` events and noise text is dropped.

### Task 7: Recreate The WuKong-Side DingTalk Client Contract

**Files:**
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_shell_models.dart`
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_shell_client.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_shell_models_test.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_shell_client_test.dart`

- [ ] Write failing Dart tests that parse the native host `/status` and `/events/recent` JSON payloads
- [ ] Mirror only the stable host contract fields needed for routing and display:
  ```dart
  class DingTalkMonitorMessageEvent {
    const DingTalkMonitorMessageEvent({
      required this.eventId,
      required this.sourceConversationId,
      required this.sourceConversationName,
      required this.embeddedSourceName,
      required this.senderName,
      required this.text,
      required this.localImagePath,
      required this.captureSource,
      required this.observedAt,
    });
  }
  ```
- [ ] Keep the shell client loopback-only and token-authenticated
- [ ] Do not reintroduce any Flutter-side DingTalk host logic; this module is client-only
- [ ] Run:
  - `flutter test test/modules/dingtalk_monitor/dingtalk_monitor_shell_models_test.dart test/modules/dingtalk_monitor/dingtalk_monitor_shell_client_test.dart`

### Task 8: Recreate The WuKong DingTalk Route UI

**Files:**
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_settings.dart`
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service.dart`
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_center_page.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_settings_test.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service_test.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_center_page_test.dart`

- [ ] Model the route settings after the Feishu monitor, but keep them scoped to the new native host contract
- [ ] Add failing tests for:
  - route match by `sourceConversationId`
  - route match by `embeddedSourceName` before outer conversation name
  - disabled route skip accounting
  - image event formatting as local-file relay candidates
- [ ] Implement a first WuKong-side center page with:
  - host online/offline status
  - recent events table
  - route mapping to target WuKong groups
  - manual forward button
- [ ] Reuse `LocalMonitorRelayIdentity` and `ApiChatSceneGateway.sendMessageContent(...)` through the same style as the Feishu path
- [ ] Run:
  - `flutter test test/modules/dingtalk_monitor/dingtalk_monitor_settings_test.dart test/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service_test.dart test/modules/dingtalk_monitor/dingtalk_monitor_center_page_test.dart`

### Task 9: Add WuKong-Side Auto Forward Runner

**Files:**
- Create: `lib/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/wukong_uikit/setting/setting_page.dart`
- Modify: `lib/wukong_uikit/setting/setting_slot_assembly.dart`
- Modify: `lib/wk_endpoint/slots/settings_slots.dart`
- Create: `test/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner_test.dart`
- Modify: `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`

- [ ] Add failing runner tests for:
  - logged-in start
  - logout stop
  - skip when no routes are enabled
  - dedupe on repeated recent-event polls
- [ ] Implement polling against the native host client, not against any in-process DingTalk runtime
- [ ] Re-add the DingTalk entry in settings only after the native host client and route UI tests are green
- [ ] Update `app.dart` so the runner starts and stops with auth state, mirroring the Feishu auto-forward lifecycle
- [ ] Run:
  - `flutter test test/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
  - `flutter analyze lib/modules/dingtalk_monitor lib/app/app.dart lib/wukong_uikit/setting lib/wk_endpoint/slots`

### Final Verification

- [ ] Native host tests pass:
  - `dotnet test tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
- [ ] Native host builds:
  - `dotnet build tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
- [ ] WuKong-side DingTalk tests pass:
  - `flutter test test/modules/dingtalk_monitor`
- [ ] WuKong-side relay regressions stay green:
  - `flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`
- [ ] Manual end-to-end:
  1. launch the native host
  2. attach DingTalk
  3. confirm `/events/recent` emits one text event
  4. open WuKong DingTalk monitor center
  5. create one route to a WuKong group
  6. forward one text event
  7. forward one image event
  8. confirm duplicate polling does not resend either event

## Risks And Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DingTalk UI tree changes frequently | High | Keep selectors centralized in `UiaChatSurfaceProbe` and add fixture-backed tests |
| Image messages do not expose usable UIA metadata | High | Fallback to preview-save or chat-area screenshot without blocking text capture |
| OCR quality is inconsistent on Chinese UI | Medium | Make OCR opt-in for M2, filter aggressively, and keep UIA text path primary |
| WuKong-side integration reintroduces host logic | Medium | Keep DingTalk Flutter module client-only and forbid any embedded runtime code |
| Long-running host drifts after popups or login expiry | High | Supervisor loop tracks HWND, login state, and attach failures separately from relay logic |

## Spec Coverage Check

- Native host separation: covered by Tasks 1-4
- Fixed WPF host and HWND embedding: covered by Task 2
- UIA text observation: covered by Task 3
- SQLite `raw_events`, `forward_jobs`, `delivery_logs`: covered by Task 4
- Image capture and screenshot fallback: covered by Task 5
- OCR fallback: covered by Task 6
- WuKong relay path using existing send abstractions: covered by Tasks 7-9
- No revival of the old Flutter DingTalk shell: enforced by Tasks 7-9 and the plan boundaries
