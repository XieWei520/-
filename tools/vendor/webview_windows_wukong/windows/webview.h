#pragma once

#include <WebView2.h>
#include <wil/com.h>
#include <windows.ui.composition.desktop.h>
#include <windows.ui.composition.h>
#include <winrt/base.h>

#include <atomic>
#include <deque>
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>

class WebviewHost;

enum class WebviewLoadingState { None, Loading, NavigationCompleted };

enum class WebviewPointerButton { None, Primary, Secondary, Tertiary };

enum class WebviewPointerEventKind { Activate, Down, Enter, Leave, Up, Update };

enum class WebviewPermissionKind {
  Unknown,
  Microphone,
  Camera,
  GeoLocation,
  Notifications,
  OtherSensors,
  ClipboardRead
};

enum class WebviewPermissionState { Default, Allow, Deny };

enum class WebviewPopupWindowPolicy { Allow, Deny, ShowInSameWindow };

enum class WebviewHostResourceAccessKind { Deny, Allow, DenyCors };

struct WebviewHistoryChanged {
  BOOL can_go_back;
  BOOL can_go_forward;
};

struct WebviewNetworkEvent {
  std::string id;
  std::string observed_at;
  std::string source;
  std::string url;
  std::string method;
  int status_code = 0;
  std::string mime_type;
  std::string payload_preview;
};

struct WebviewNetworkCaptureStartResult {
  bool success = false;
  std::string error_message;
};

struct VirtualKeyState {
 public:
  inline void set_isLeftButtonDown(bool is_down) {
    set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
            COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_LEFT_BUTTON,
        is_down);
  }

  inline void set_isRightButtonDown(bool is_down) {
    set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
            COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_RIGHT_BUTTON,
        is_down);
  }

  inline void set_isMiddleButtonDown(bool is_down) {
    set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
            COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_MIDDLE_BUTTON,
        is_down);
  }

  inline COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS state() const { return state_; }

 private:
  COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS state_ =
      COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS::
          COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS_NONE;

  inline void set(COREWEBVIEW2_MOUSE_EVENT_VIRTUAL_KEYS key, bool flag) {
    if (flag) {
      state_ |= key;
    } else {
      state_ &= ~key;
    }
  }
};

struct EventRegistrations {
  bool has_source_changed_token_ = false;
  bool has_content_loading_token_ = false;
  bool has_navigation_completed_token_ = false;
  bool has_history_changed_token_ = false;
  bool has_document_title_changed_token_ = false;
  bool has_cursor_changed_token_ = false;
  bool has_got_focus_token_ = false;
  bool has_lost_focus_token_ = false;
  bool has_web_message_received_token_ = false;
  bool has_permission_requested_token_ = false;
  bool has_devtools_protocol_event_token_ = false;
  bool has_network_response_received_token_ = false;
  bool has_network_loading_finished_token_ = false;
  bool has_network_websocket_frame_received_token_ = false;
  bool has_new_windows_requested_token_ = false;
  bool has_contains_fullscreen_element_changed_token_ = false;
  EventRegistrationToken source_changed_token_{};
  EventRegistrationToken content_loading_token_{};
  EventRegistrationToken navigation_completed_token_{};
  EventRegistrationToken history_changed_token_{};
  EventRegistrationToken document_title_changed_token_{};
  EventRegistrationToken cursor_changed_token_{};
  EventRegistrationToken got_focus_token_{};
  EventRegistrationToken lost_focus_token_{};
  EventRegistrationToken web_message_received_token_{};
  EventRegistrationToken permission_requested_token_{};
  EventRegistrationToken devtools_protocol_event_token_{};
  EventRegistrationToken network_response_received_token_{};
  EventRegistrationToken network_loading_finished_token_{};
  EventRegistrationToken network_websocket_frame_received_token_{};
  EventRegistrationToken new_windows_requested_token_{};
  EventRegistrationToken contains_fullscreen_element_changed_token_{};
};

class Webview {
 public:
  friend class WebviewHost;

  typedef std::function<void(const std::string&)> UrlChangedCallback;
  typedef std::function<void(WebviewLoadingState)> LoadingStateChangedCallback;
  typedef std::function<void(COREWEBVIEW2_WEB_ERROR_STATUS)>
      OnLoadErrorCallback;
  typedef std::function<void(WebviewHistoryChanged)> HistoryChangedCallback;
  typedef std::function<void(const std::string&)> DevtoolsProtocolEventCallback;
  typedef std::function<void(const WebviewNetworkEvent&)>
      NetworkEventCallback;
  typedef std::function<void(const std::string&)> DocumentTitleChangedCallback;
  typedef std::function<void(size_t width, size_t height)>
      SurfaceSizeChangedCallback;
  typedef std::function<void(const HCURSOR)> CursorChangedCallback;
  typedef std::function<void(bool)> FocusChangedCallback;
  typedef std::function<void(bool, const std::string&)>
      AddScriptToExecuteOnDocumentCreatedCallback;
  typedef std::function<void(bool, const std::string&)> ScriptExecutedCallback;
  typedef std::function<void(const std::string&)> WebMessageReceivedCallback;
  typedef std::function<void(WebviewPermissionState state)>
      WebviewPermissionRequestedCompleter;
  typedef std::function<void(const std::string& url, WebviewPermissionKind kind,
                             bool is_user_initiated,
                             WebviewPermissionRequestedCompleter completer)>
      PermissionRequestedCallback;
  typedef std::function<void(bool contains_fullscreen_element)>
      ContainsFullScreenElementChangedCallback;

  ~Webview();

  ABI::Windows::UI::Composition::IVisual* const surface() {
    return surface_.get();
  }

  bool IsValid() { return is_valid_; }

  void SetSurfaceSize(size_t width, size_t height, float scale_factor);
  void SetCursorPos(double x, double y);
  void SetPointerUpdate(int32_t pointer, WebviewPointerEventKind eventKind,
                        double x, double y, double size, double pressure);
  void SetPointerButtonState(WebviewPointerButton button, bool isDown);
  void SetScrollDelta(double delta_x, double delta_y);
  void LoadUrl(const std::string& url);
  void LoadStringContent(const std::string& content);
  bool Stop();
  bool Reload();
  bool GoBack();
  bool GoForward();
  void AddScriptToExecuteOnDocumentCreated(
      const std::string& script,
      AddScriptToExecuteOnDocumentCreatedCallback callback);
  void RemoveScriptToExecuteOnDocumentCreated(const std::string& script_id);
  void ExecuteScript(const std::string& script,
                     ScriptExecutedCallback callback);
  bool PostWebMessage(const std::string& json);
  bool ClearCookies();
  bool ClearCache();
  bool SetCacheDisabled(bool disabled);
  WebviewNetworkCaptureStartResult StartNetworkCapture();
  bool StopNetworkCapture();
  void SetPopupWindowPolicy(WebviewPopupWindowPolicy policy);
  bool SetUserAgent(const std::string& user_agent);
  bool OpenDevTools();
  bool SetBackgroundColor(int32_t color);
  bool SetZoomFactor(double factor);
  bool Suspend();
  bool Resume();

  bool SetVirtualHostNameMapping(const std::string& hostName,
                                 const std::string& path,
                                 WebviewHostResourceAccessKind accessKind);
  bool ClearVirtualHostNameMapping(const std::string& hostName);

  void OnUrlChanged(UrlChangedCallback callback) {
    url_changed_callback_ = std::move(callback);
  }

  void OnLoadError(OnLoadErrorCallback callback) {
    on_load_error_callback_ = std::move(callback);
  }

  void OnLoadingStateChanged(LoadingStateChangedCallback callback) {
    loading_state_changed_callback_ = std::move(callback);
  }

  void OnHistoryChanged(HistoryChangedCallback callback) {
    history_changed_callback_ = std::move(callback);
  }

  void OnSurfaceSizeChanged(SurfaceSizeChangedCallback callback) {
    surface_size_changed_callback_ = std::move(callback);
  }

  void OnDocumentTitleChanged(DocumentTitleChangedCallback callback) {
    document_title_changed_callback_ = std::move(callback);
  }

  void OnCursorChanged(CursorChangedCallback callback) {
    cursor_changed_callback_ = std::move(callback);
  }

  void OnFocusChanged(FocusChangedCallback callback) {
    focus_changed_callback_ = std::move(callback);
  }

  void OnWebMessageReceived(WebMessageReceivedCallback callback) {
    web_message_received_callback_ = std::move(callback);
  }

  void OnPermissionRequested(PermissionRequestedCallback callback) {
    permission_requested_callback_ = std::move(callback);
  }

  void OnDevtoolsProtocolEvent(DevtoolsProtocolEventCallback callback) {
    devtools_protocol_event_callback_ = std::move(callback);
  }

  void OnNetworkEvent(NetworkEventCallback callback) {
    network_event_callback_ = std::move(callback);
  }

  void OnContainsFullScreenElementChanged(
      ContainsFullScreenElementChangedCallback callback) {
    contains_fullscreen_element_changed_callback_ = std::move(callback);
  }

 private:
  HWND hwnd_;
  bool owns_window_;
  bool is_valid_ = false;
  float scale_factor_ = 1.0;
  wil::com_ptr<ICoreWebView2CompositionController> composition_controller_;
  wil::com_ptr<ICoreWebView2Controller3> webview_controller_;
  wil::com_ptr<ICoreWebView2> webview_;
  wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver>
      devtools_protocol_event_receiver_;
  wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver>
      network_response_received_receiver_;
  wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver>
      network_loading_finished_receiver_;
  wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver>
      network_websocket_frame_received_receiver_;
  wil::com_ptr<ICoreWebView2Settings2> settings2_;
  POINT last_cursor_pos_ = {0, 0};
  VirtualKeyState virtual_keys_;
  WebviewPopupWindowPolicy popup_window_policy_ =
      WebviewPopupWindowPolicy::Allow;

  winrt::com_ptr<ABI::Windows::UI::Composition::IVisual> surface_;
  winrt::com_ptr<ABI::Windows::UI::Composition::Desktop::IDesktopWindowTarget>
      window_target_;

  WebviewHost* host_;
  EventRegistrations event_registrations_{};

  UrlChangedCallback url_changed_callback_;
  LoadingStateChangedCallback loading_state_changed_callback_;
  OnLoadErrorCallback on_load_error_callback_;
  HistoryChangedCallback history_changed_callback_;
  DocumentTitleChangedCallback document_title_changed_callback_;
  SurfaceSizeChangedCallback surface_size_changed_callback_;
  CursorChangedCallback cursor_changed_callback_;
  FocusChangedCallback focus_changed_callback_;
  WebMessageReceivedCallback web_message_received_callback_;
  PermissionRequestedCallback permission_requested_callback_;
  DevtoolsProtocolEventCallback devtools_protocol_event_callback_;
  NetworkEventCallback network_event_callback_;
  ContainsFullScreenElementChangedCallback
      contains_fullscreen_element_changed_callback_;
  std::shared_ptr<std::atomic_bool> lifetime_token_ =
      std::make_shared<std::atomic_bool>(true);
  bool network_capture_enabled_ = false;
  std::unordered_map<std::string, WebviewNetworkEvent> pending_network_events_;
  std::deque<std::string> pending_network_event_order_;

  Webview(
      wil::com_ptr<ICoreWebView2CompositionController> composition_controller,
      WebviewHost* host, HWND hwnd, bool owns_window, bool offscreen_only);

  bool CreateSurface(
      winrt::com_ptr<ABI::Windows::UI::Composition::ICompositor> compositor,
      HWND hwnd, bool offscreen_only);
  void RegisterEventHandlers();
  void EnableSecurityUpdates();
  void CleanupEventHandlers();
  void CleanupNetworkCapture();
  WebviewNetworkCaptureStartResult FailNetworkCaptureStart(
      const std::string& message);
  void StorePendingNetworkEvent(const WebviewNetworkEvent& event);
  void HandleNetworkResponseReceived(const std::string& json);
  void HandleNetworkLoadingFinished(const std::string& json);
  void HandleNetworkWebSocketFrameReceived(const std::string& json);
  void EmitNetworkEvent(const WebviewNetworkEvent& event);
  void SendScroll(double offset, bool horizontal);
};
