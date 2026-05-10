#include "webview.h"

#include <wrl.h>

#include <algorithm>
#include <chrono>
#include <ctime>
#include <cctype>
#include <format>
#include <iomanip>
#include <iostream>
#include <sstream>

#include "util/composition.desktop.interop.h"
#include "util/string_converter.h"
#include "webview_host.h"

using namespace Microsoft::WRL;

namespace {

constexpr size_t kMaxPayloadPreviewBytes = 16 * 1024;
constexpr size_t kMaxPendingNetworkEvents = 256;

inline void ConvertColor(COREWEBVIEW2_COLOR& webview_color, int32_t color) {
  webview_color.B = color & 0xFF;
  webview_color.G = (color >> 8) & 0xFF;
  webview_color.R = (color >> 16) & 0xFF;
  webview_color.A = (color >> 24) & 0xFF;
}

inline WebviewPermissionKind CW2PermissionKindToPermissionKind(
    COREWEBVIEW2_PERMISSION_KIND kind) {
  using k = COREWEBVIEW2_PERMISSION_KIND;
  switch (kind) {
    case k::COREWEBVIEW2_PERMISSION_KIND_MICROPHONE:
      return WebviewPermissionKind::Microphone;
    case k::COREWEBVIEW2_PERMISSION_KIND_CAMERA:
      return WebviewPermissionKind::Camera;
    case k::COREWEBVIEW2_PERMISSION_KIND_GEOLOCATION:
      return WebviewPermissionKind::GeoLocation;
    case k::COREWEBVIEW2_PERMISSION_KIND_NOTIFICATIONS:
      return WebviewPermissionKind::Notifications;
    case k::COREWEBVIEW2_PERMISSION_KIND_OTHER_SENSORS:
      return WebviewPermissionKind::OtherSensors;
    case k::COREWEBVIEW2_PERMISSION_KIND_CLIPBOARD_READ:
      return WebviewPermissionKind::ClipboardRead;
    default:
      return WebviewPermissionKind::Unknown;
  }
}

inline COREWEBVIEW2_PERMISSION_STATE WebViewPermissionStateToCW2PermissionState(
    WebviewPermissionState state) {
  using s = COREWEBVIEW2_PERMISSION_STATE;
  switch (state) {
    case WebviewPermissionState::Allow:
      return s::COREWEBVIEW2_PERMISSION_STATE_ALLOW;
    case WebviewPermissionState::Deny:
      return s::COREWEBVIEW2_PERMISSION_STATE_DENY;
    default:
      return s::COREWEBVIEW2_PERMISSION_STATE_DEFAULT;
  }
}

std::string NowIso8601Utc() {
  const auto now = std::chrono::system_clock::now();
  const auto time = std::chrono::system_clock::to_time_t(now);
  std::tm utc = {};
  gmtime_s(&utc, &time);
  std::ostringstream stream;
  stream << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");
  return stream.str();
}

std::string TruncatePreview(const std::string& value) {
  if (value.size() <= kMaxPayloadPreviewBytes) {
    return value;
  }
  return value.substr(0, kMaxPayloadPreviewBytes);
}

std::string JsonStringValue(const std::string& json, const std::string& key) {
  const auto key_pos = json.find("\"" + key + "\"");
  if (key_pos == std::string::npos) {
    return "";
  }
  const auto colon_pos = json.find(':', key_pos);
  if (colon_pos == std::string::npos) {
    return "";
  }
  const auto quote_pos = json.find('"', colon_pos + 1);
  if (quote_pos == std::string::npos) {
    return "";
  }

  std::string value;
  bool escaped = false;
  for (size_t i = quote_pos + 1; i < json.size(); ++i) {
    const char ch = json[i];
    if (escaped) {
      switch (ch) {
        case '"':
        case '\\':
        case '/':
          value.push_back(ch);
          break;
        case 'b':
          value.push_back('\b');
          break;
        case 'f':
          value.push_back('\f');
          break;
        case 'n':
          value.push_back('\n');
          break;
        case 'r':
          value.push_back('\r');
          break;
        case 't':
          value.push_back('\t');
          break;
        case 'u':
          value.append("\\u");
          if (i + 4 < json.size()) {
            value.append(json.substr(i + 1, 4));
            i += 4;
          }
          break;
        default:
          value.push_back(ch);
          break;
      }
      escaped = false;
      continue;
    }
    if (ch == '\\') {
      escaped = true;
      continue;
    }
    if (ch == '"') {
      return value;
    }
    value.push_back(ch);
  }
  return value;
}

int JsonIntValue(const std::string& json, const std::string& key) {
  const auto key_pos = json.find("\"" + key + "\"");
  if (key_pos == std::string::npos) {
    return 0;
  }
  const auto colon_pos = json.find(':', key_pos);
  if (colon_pos == std::string::npos) {
    return 0;
  }
  const auto start = json.find_first_of("-0123456789", colon_pos + 1);
  if (start == std::string::npos) {
    return 0;
  }
  const auto end = json.find_first_not_of("0123456789", start + 1);
  try {
    return std::stoi(json.substr(start, end - start));
  } catch (...) {
    return 0;
  }
}

bool JsonHasKey(const std::string& json, const std::string& key) {
  return json.find("\"" + key + "\"") != std::string::npos;
}

bool ShouldReadResponseBody(const WebviewNetworkEvent& event) {
  std::string probe = event.mime_type + " " + event.url;
  std::transform(probe.begin(), probe.end(), probe.begin(),
                 [](unsigned char c) {
                   return static_cast<char>(std::tolower(c));
                 });
  return probe.find("json") != std::string::npos ||
         probe.find("text") != std::string::npos ||
         probe.find("messenger") != std::string::npos ||
         probe.find("message") != std::string::npos ||
         probe.find("image") != std::string::npos ||
         probe.find("resource") != std::string::npos;
}

}  // namespace

Webview::Webview(
    wil::com_ptr<ICoreWebView2CompositionController> composition_controller,
    WebviewHost* host, HWND hwnd, bool owns_window, bool offscreen_only)
    : composition_controller_(std::move(composition_controller)),
      host_(host),
      hwnd_(hwnd),
      owns_window_(owns_window) {
  webview_controller_ =
      composition_controller_.try_query<ICoreWebView2Controller3>();

  if (!webview_controller_ ||
      FAILED(webview_controller_->get_CoreWebView2(webview_.put()))) {
    return;
  }

  webview_controller_->put_BoundsMode(COREWEBVIEW2_BOUNDS_MODE_USE_RAW_PIXELS);
  webview_controller_->put_ShouldDetectMonitorScaleChanges(FALSE);
  webview_controller_->put_RasterizationScale(1.0);

  wil::com_ptr<ICoreWebView2Settings> settings;
  if (SUCCEEDED(webview_->get_Settings(settings.put()))) {
    settings2_ = settings.try_query<ICoreWebView2Settings2>();

    settings->put_IsStatusBarEnabled(FALSE);
    settings->put_AreDefaultContextMenusEnabled(FALSE);
  }

  EnableSecurityUpdates();
  RegisterEventHandlers();

  is_valid_ = CreateSurface(host->compositor(), hwnd, offscreen_only);
}

Webview::~Webview() {
  lifetime_token_->store(false);
  CleanupEventHandlers();
  CleanupNetworkCapture();
  if (owns_window_) {
    DestroyWindow(hwnd_);
  }
}

bool Webview::CreateSurface(
    winrt::com_ptr<ABI::Windows::UI::Composition::ICompositor> compositor,
    HWND hwnd, bool offscreen_only) {
  winrt::com_ptr<ABI::Windows::UI::Composition::IContainerVisual> root;
  if (FAILED(compositor->CreateContainerVisual(root.put()))) {
    return false;
  }

  surface_ = root.try_as<ABI::Windows::UI::Composition::IVisual>();
  assert(surface_);

  // initial size. doesn't matter as we resize the surface anyway.
  surface_->put_Size({1280, 720});
  surface_->put_IsVisible(true);

  // Create on-screen window for debugging purposes
  if (!offscreen_only) {
    window_target_ = util::TryCreateDesktopWindowTarget(compositor, hwnd);
    auto composition_target =
        window_target_
            .try_as<ABI::Windows::UI::Composition::ICompositionTarget>();
    if (composition_target) {
      composition_target->put_Root(surface_.get());
    }
  }

  winrt::com_ptr<ABI::Windows::UI::Composition::IVisual> webview_visual;
  compositor->CreateContainerVisual(
      reinterpret_cast<ABI::Windows::UI::Composition::IContainerVisual**>(
          webview_visual.put()));

  auto webview_visual2 =
      webview_visual.try_as<ABI::Windows::UI::Composition::IVisual2>();
  if (webview_visual2) {
    webview_visual2->put_RelativeSizeAdjustment({1.0f, 1.0f});
  }

  winrt::com_ptr<ABI::Windows::UI::Composition::IVisualCollection> children;
  root->get_Children(children.put());
  children->InsertAtTop(webview_visual.get());
  composition_controller_->put_RootVisualTarget(webview_visual2.get());

  webview_controller_->put_IsVisible(true);

  return true;
}

void Webview::EnableSecurityUpdates() {
  if (SUCCEEDED(webview_->CallDevToolsProtocolMethod(L"Security.enable", L"{}",
                                                     nullptr)) &&
      SUCCEEDED(webview_->GetDevToolsProtocolEventReceiver(
          L"Security.securityStateChanged",
          &devtools_protocol_event_receiver_))) {
    if (SUCCEEDED(devtools_protocol_event_receiver_
                      ->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
            [this](ICoreWebView2* sender,
                   ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args)
                -> HRESULT {
              if (devtools_protocol_event_callback_) {
                wil::unique_cotaskmem_string json_args;
                if (args->get_ParameterObjectAsJson(&json_args) == S_OK) {
                  std::string json = util::Utf8FromUtf16(json_args.get());
                  devtools_protocol_event_callback_(json.c_str());
                }
              }

              return S_OK;
            })
            .Get(),
        &event_registrations_.devtools_protocol_event_token_))) {
      event_registrations_.has_devtools_protocol_event_token_ = true;
    }
  }
}

void Webview::CleanupEventHandlers() {
  if (webview_) {
    if (event_registrations_.has_source_changed_token_) {
      webview_->remove_SourceChanged(
          event_registrations_.source_changed_token_);
    }
    if (event_registrations_.has_content_loading_token_) {
      webview_->remove_ContentLoading(
          event_registrations_.content_loading_token_);
    }
    if (event_registrations_.has_navigation_completed_token_) {
      webview_->remove_NavigationCompleted(
          event_registrations_.navigation_completed_token_);
    }
    if (event_registrations_.has_history_changed_token_) {
      webview_->remove_HistoryChanged(
          event_registrations_.history_changed_token_);
    }
    if (event_registrations_.has_document_title_changed_token_) {
      webview_->remove_DocumentTitleChanged(
          event_registrations_.document_title_changed_token_);
    }
    if (event_registrations_.has_web_message_received_token_) {
      webview_->remove_WebMessageReceived(
          event_registrations_.web_message_received_token_);
    }
    if (event_registrations_.has_permission_requested_token_) {
      webview_->remove_PermissionRequested(
          event_registrations_.permission_requested_token_);
    }
    if (event_registrations_.has_new_windows_requested_token_) {
      webview_->remove_NewWindowRequested(
          event_registrations_.new_windows_requested_token_);
    }
    if (event_registrations_.has_contains_fullscreen_element_changed_token_) {
      webview_->remove_ContainsFullScreenElementChanged(
          event_registrations_.contains_fullscreen_element_changed_token_);
    }
  }
  if (webview_controller_) {
    if (event_registrations_.has_got_focus_token_) {
      webview_controller_->remove_GotFocus(
          event_registrations_.got_focus_token_);
    }
    if (event_registrations_.has_lost_focus_token_) {
      webview_controller_->remove_LostFocus(
          event_registrations_.lost_focus_token_);
    }
  }
  if (composition_controller_ && event_registrations_.has_cursor_changed_token_) {
    composition_controller_->remove_CursorChanged(
        event_registrations_.cursor_changed_token_);
  }
  if (devtools_protocol_event_receiver_ &&
      event_registrations_.has_devtools_protocol_event_token_) {
    devtools_protocol_event_receiver_->remove_DevToolsProtocolEventReceived(
        event_registrations_.devtools_protocol_event_token_);
    devtools_protocol_event_receiver_.reset();
  }

  event_registrations_.has_source_changed_token_ = false;
  event_registrations_.has_content_loading_token_ = false;
  event_registrations_.has_navigation_completed_token_ = false;
  event_registrations_.has_history_changed_token_ = false;
  event_registrations_.has_document_title_changed_token_ = false;
  event_registrations_.has_cursor_changed_token_ = false;
  event_registrations_.has_got_focus_token_ = false;
  event_registrations_.has_lost_focus_token_ = false;
  event_registrations_.has_web_message_received_token_ = false;
  event_registrations_.has_permission_requested_token_ = false;
  event_registrations_.has_devtools_protocol_event_token_ = false;
  event_registrations_.has_new_windows_requested_token_ = false;
  event_registrations_.has_contains_fullscreen_element_changed_token_ = false;
  event_registrations_.source_changed_token_ = {};
  event_registrations_.content_loading_token_ = {};
  event_registrations_.navigation_completed_token_ = {};
  event_registrations_.history_changed_token_ = {};
  event_registrations_.document_title_changed_token_ = {};
  event_registrations_.cursor_changed_token_ = {};
  event_registrations_.got_focus_token_ = {};
  event_registrations_.lost_focus_token_ = {};
  event_registrations_.web_message_received_token_ = {};
  event_registrations_.permission_requested_token_ = {};
  event_registrations_.devtools_protocol_event_token_ = {};
  event_registrations_.new_windows_requested_token_ = {};
  event_registrations_.contains_fullscreen_element_changed_token_ = {};

  url_changed_callback_ = nullptr;
  loading_state_changed_callback_ = nullptr;
  on_load_error_callback_ = nullptr;
  history_changed_callback_ = nullptr;
  document_title_changed_callback_ = nullptr;
  surface_size_changed_callback_ = nullptr;
  cursor_changed_callback_ = nullptr;
  focus_changed_callback_ = nullptr;
  web_message_received_callback_ = nullptr;
  permission_requested_callback_ = nullptr;
  devtools_protocol_event_callback_ = nullptr;
  network_event_callback_ = nullptr;
  contains_fullscreen_element_changed_callback_ = nullptr;
}

void Webview::RegisterEventHandlers() {
  if (!webview_) {
    return;
  }

  if (SUCCEEDED(webview_->add_ContentLoading(
      Callback<ICoreWebView2ContentLoadingEventHandler>(
          [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            if (loading_state_changed_callback_) {
              loading_state_changed_callback_(WebviewLoadingState::Loading);
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.content_loading_token_))) {
    event_registrations_.has_content_loading_token_ = true;
  }

  if (SUCCEEDED(webview_->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
          [this](ICoreWebView2* sender,
                 ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
            BOOL is_success;
            args->get_IsSuccess(&is_success);
            if (!is_success && on_load_error_callback_) {
              COREWEBVIEW2_WEB_ERROR_STATUS web_error_status;
              args->get_WebErrorStatus(&web_error_status);
              on_load_error_callback_(web_error_status);
            }

            if (loading_state_changed_callback_) {
              loading_state_changed_callback_(
                  WebviewLoadingState::NavigationCompleted);
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.navigation_completed_token_))) {
    event_registrations_.has_navigation_completed_token_ = true;
  }

  if (SUCCEEDED(webview_->add_HistoryChanged(
      Callback<ICoreWebView2HistoryChangedEventHandler>(
          [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            if (history_changed_callback_) {
              BOOL can_go_back;
              BOOL can_go_forward;
              sender->get_CanGoBack(&can_go_back);
              sender->get_CanGoForward(&can_go_forward);
              history_changed_callback_({can_go_back, can_go_forward});
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.history_changed_token_))) {
    event_registrations_.has_history_changed_token_ = true;
  }

  if (SUCCEEDED(webview_->add_SourceChanged(
      Callback<ICoreWebView2SourceChangedEventHandler>(
          [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            LPWSTR wurl;
            if (url_changed_callback_ && webview_->get_Source(&wurl) == S_OK) {
              std::string url = util::Utf8FromUtf16(wurl);
              url_changed_callback_(url);
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.source_changed_token_))) {
    event_registrations_.has_source_changed_token_ = true;
  }

  if (SUCCEEDED(webview_->add_DocumentTitleChanged(
      Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
          [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            LPWSTR wtitle;
            if (document_title_changed_callback_ &&
                webview_->get_DocumentTitle(&wtitle) == S_OK) {
              std::string title = util::Utf8FromUtf16(wtitle);
              document_title_changed_callback_(title);
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.document_title_changed_token_))) {
    event_registrations_.has_document_title_changed_token_ = true;
  }

  if (SUCCEEDED(composition_controller_->add_CursorChanged(
      Callback<ICoreWebView2CursorChangedEventHandler>(
          [this](ICoreWebView2CompositionController* sender,
                 IUnknown* args) -> HRESULT {
            HCURSOR cursor;
            if (cursor_changed_callback_ &&
                sender->get_Cursor(&cursor) == S_OK) {
              cursor_changed_callback_(cursor);
            }
            return S_OK;
          })
          .Get(),
      &event_registrations_.cursor_changed_token_))) {
    event_registrations_.has_cursor_changed_token_ = true;
  }

  if (SUCCEEDED(webview_controller_->add_GotFocus(
      Callback<ICoreWebView2FocusChangedEventHandler>(
          [this](ICoreWebView2Controller* sender, IUnknown* args) -> HRESULT {
            if (focus_changed_callback_) {
              focus_changed_callback_(true);
            }
            return S_OK;
          })
          .Get(),
      &event_registrations_.got_focus_token_))) {
    event_registrations_.has_got_focus_token_ = true;
  }

  if (SUCCEEDED(webview_controller_->add_LostFocus(
      Callback<ICoreWebView2FocusChangedEventHandler>(
          [this](ICoreWebView2Controller* sender, IUnknown* args) -> HRESULT {
            if (focus_changed_callback_) {
              focus_changed_callback_(false);
            }
            return S_OK;
          })
          .Get(),
      &event_registrations_.lost_focus_token_))) {
    event_registrations_.has_lost_focus_token_ = true;
  }

  if (SUCCEEDED(webview_->add_WebMessageReceived(
      Callback<ICoreWebView2WebMessageReceivedEventHandler>(
          [this](ICoreWebView2* sender,
                 ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
            wil::unique_cotaskmem_string wmessage;
            if (web_message_received_callback_ &&
                args->get_WebMessageAsJson(&wmessage) == S_OK) {
              const std::string message = util::Utf8FromUtf16(wmessage.get());
              web_message_received_callback_(message);
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.web_message_received_token_))) {
    event_registrations_.has_web_message_received_token_ = true;
  }

  if (SUCCEEDED(webview_->add_PermissionRequested(
      Callback<ICoreWebView2PermissionRequestedEventHandler>(
          [this](ICoreWebView2* sender,
                 ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
            if (!permission_requested_callback_) {
              return S_OK;
            }

            wil::unique_cotaskmem_string wuri;
            COREWEBVIEW2_PERMISSION_KIND kind =
                COREWEBVIEW2_PERMISSION_KIND_UNKNOWN_PERMISSION;
            BOOL is_user_initiated = false;

            if (args->get_Uri(&wuri) == S_OK &&
                args->get_PermissionKind(&kind) == S_OK &&
                args->get_IsUserInitiated(&is_user_initiated) == S_OK) {
              wil::com_ptr<ICoreWebView2Deferral> deferral;
              args->GetDeferral(deferral.put());

              const std::string uri = util::Utf8FromUtf16(wuri.get());
              permission_requested_callback_(
                  uri, CW2PermissionKindToPermissionKind(kind),
                  is_user_initiated == TRUE,
                  [deferral = std::move(deferral),
                   args = std::move(args)](WebviewPermissionState state) {
                    args->put_State(
                        WebViewPermissionStateToCW2PermissionState(state));
                    deferral->Complete();
                  });
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.permission_requested_token_))) {
    event_registrations_.has_permission_requested_token_ = true;
  }

  if (SUCCEEDED(webview_->add_NewWindowRequested(
      Callback<ICoreWebView2NewWindowRequestedEventHandler>(
          [this](ICoreWebView2* sender,
                 ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
            switch (popup_window_policy_) {
              case WebviewPopupWindowPolicy::Deny:
                args->put_Handled(TRUE);
                break;
              case WebviewPopupWindowPolicy::ShowInSameWindow:
                args->put_NewWindow(webview_.get());
                args->put_Handled(TRUE);
                break;
            }

            return S_OK;
          })
          .Get(),
      &event_registrations_.new_windows_requested_token_))) {
    event_registrations_.has_new_windows_requested_token_ = true;
  }

  if (SUCCEEDED(webview_->add_ContainsFullScreenElementChanged(
      Callback<ICoreWebView2ContainsFullScreenElementChangedEventHandler>(
          [this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
            BOOL flag = FALSE;
            if (contains_fullscreen_element_changed_callback_ &&
                SUCCEEDED(sender->get_ContainsFullScreenElement(&flag))) {
              contains_fullscreen_element_changed_callback_(flag);
            }
            return S_OK;
          })
          .Get(),
      &event_registrations_
           .contains_fullscreen_element_changed_token_))) {
    event_registrations_.has_contains_fullscreen_element_changed_token_ = true;
  }
}

void Webview::SetSurfaceSize(size_t width, size_t height, float scale_factor) {
  if (!IsValid()) {
    return;
  }

  if (surface_ && width > 0 && height > 0) {
    scale_factor_ = scale_factor;
    auto scaled_width = width * scale_factor;
    auto scaled_height = height * scale_factor;

    RECT bounds;
    bounds.left = 0;
    bounds.top = 0;
    bounds.right = static_cast<LONG>(scaled_width);
    bounds.bottom = static_cast<LONG>(scaled_height);

    surface_->put_Size({scaled_width, scaled_height});
    webview_controller_->put_RasterizationScale(scale_factor);
    if (webview_controller_->put_Bounds(bounds) != S_OK) {
      std::cerr << "Setting webview bounds failed." << std::endl;
    }

    if (surface_size_changed_callback_) {
      surface_size_changed_callback_(width, height);
    }
  }
}

bool Webview::OpenDevTools() {
  if (!IsValid()) {
    return false;
  }
  webview_->OpenDevToolsWindow();
  return true;
}

bool Webview::ClearCookies() {
  if (!IsValid()) {
    return false;
  }
  return webview_->CallDevToolsProtocolMethod(L"Network.clearBrowserCookies",
                                              L"{}", nullptr) == S_OK;
}

bool Webview::ClearCache() {
  if (!IsValid()) {
    return false;
  }
  return webview_->CallDevToolsProtocolMethod(L"Network.clearBrowserCache",
                                              L"{}", nullptr) == S_OK;
}

bool Webview::SetCacheDisabled(bool disabled) {
  if (!IsValid()) {
    return false;
  }
  std::string json = std::format("{{\"disableCache\":{}}}", disabled);
  return webview_->CallDevToolsProtocolMethod(L"Network.setCacheDisabled",
                                              util::Utf16FromUtf8(json).c_str(),
                                              nullptr) == S_OK;
}

void Webview::HandleNetworkResponseReceived(const std::string& json) {
  if (!network_capture_enabled_) {
    return;
  }

  WebviewNetworkEvent event;
  event.id = JsonStringValue(json, "requestId");
  event.observed_at = NowIso8601Utc();
  event.source = "httpResponse";
  event.url = JsonStringValue(json, "url");
  event.method = JsonStringValue(json, "method");
  event.status_code = JsonIntValue(json, "status");
  event.mime_type = JsonStringValue(json, "mimeType");

  if (event.method.empty()) {
    event.method = JsonStringValue(json, "requestMethod");
  }
  if (event.id.empty()) {
    event.id = event.url;
  }

  EmitNetworkEvent(event);

  if (!event.id.empty() && ShouldReadResponseBody(event)) {
    StorePendingNetworkEvent(event);
  }
}

void Webview::HandleNetworkLoadingFinished(const std::string& json) {
  if (!network_capture_enabled_) {
    return;
  }

  const std::string request_id = JsonStringValue(json, "requestId");
  if (request_id.empty()) {
    return;
  }

  const auto pending_it = pending_network_events_.find(request_id);
  if (pending_it == pending_network_events_.end()) {
    return;
  }

  const auto event = pending_it->second;
  pending_network_events_.erase(pending_it);
  const auto order_it =
      std::find(pending_network_event_order_.begin(),
                pending_network_event_order_.end(), request_id);
  if (order_it != pending_network_event_order_.end()) {
    pending_network_event_order_.erase(order_it);
  }

  const std::string args =
      std::format("{{\"requestId\":\"{}\"}}", request_id);
  const auto lifetime_token = lifetime_token_;
  const auto network_event_callback = network_event_callback_;
  webview_->CallDevToolsProtocolMethod(
      L"Network.getResponseBody", util::Utf16FromUtf8(args).c_str(),
      Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
          [lifetime_token, network_event_callback, event](
              HRESULT error_code, LPCWSTR return_object_as_json) -> HRESULT {
            if (!lifetime_token || !lifetime_token->load() ||
                FAILED(error_code) || !return_object_as_json ||
                !network_event_callback) {
              return S_OK;
            }

            WebviewNetworkEvent event_with_body = event;
            const std::string response_json =
                util::Utf8FromUtf16(return_object_as_json);
            event_with_body.payload_preview =
                TruncatePreview(JsonStringValue(response_json, "body"));
            network_event_callback(event_with_body);
            return S_OK;
          })
          .Get());
}

void Webview::HandleNetworkWebSocketFrameReceived(const std::string& json) {
  if (!network_capture_enabled_) {
    return;
  }

  WebviewNetworkEvent event;
  event.id = JsonStringValue(json, "requestId");
  event.observed_at = NowIso8601Utc();
  event.source = "webSocketFrame";
  event.method = "WS";
  if (JsonHasKey(json, "opcode")) {
    event.method = std::format("WS:{}", JsonIntValue(json, "opcode"));
  }
  event.mime_type = "application/octet-stream";
  event.payload_preview =
      TruncatePreview(JsonStringValue(json, "payloadData"));
  if (event.id.empty()) {
    event.id = "websocket";
  }
  EmitNetworkEvent(event);
}

void Webview::EmitNetworkEvent(const WebviewNetworkEvent& event) {
  if (network_event_callback_) {
    network_event_callback_(event);
  }
}

void Webview::CleanupNetworkCapture() {
  network_capture_enabled_ = false;
  pending_network_events_.clear();
  pending_network_event_order_.clear();

  if (network_response_received_receiver_ &&
      event_registrations_.has_network_response_received_token_) {
    network_response_received_receiver_->remove_DevToolsProtocolEventReceived(
        event_registrations_.network_response_received_token_);
  }
  network_response_received_receiver_.reset();
  event_registrations_.has_network_response_received_token_ = false;
  event_registrations_.network_response_received_token_ = {};

  if (network_loading_finished_receiver_ &&
      event_registrations_.has_network_loading_finished_token_) {
    network_loading_finished_receiver_->remove_DevToolsProtocolEventReceived(
        event_registrations_.network_loading_finished_token_);
  }
  network_loading_finished_receiver_.reset();
  event_registrations_.has_network_loading_finished_token_ = false;
  event_registrations_.network_loading_finished_token_ = {};

  if (network_websocket_frame_received_receiver_ &&
      event_registrations_.has_network_websocket_frame_received_token_) {
    network_websocket_frame_received_receiver_
        ->remove_DevToolsProtocolEventReceived(
            event_registrations_.network_websocket_frame_received_token_);
  }
  network_websocket_frame_received_receiver_.reset();
  event_registrations_.has_network_websocket_frame_received_token_ = false;
  event_registrations_.network_websocket_frame_received_token_ = {};

  if (webview_) {
    webview_->CallDevToolsProtocolMethod(L"Network.disable", L"{}", nullptr);
  }
}

WebviewNetworkCaptureStartResult Webview::FailNetworkCaptureStart(
    const std::string& message) {
  CleanupNetworkCapture();
  return {false, message};
}

void Webview::StorePendingNetworkEvent(const WebviewNetworkEvent& event) {
  const bool existing =
      pending_network_events_.find(event.id) != pending_network_events_.end();
  pending_network_events_[event.id] = event;
  if (!existing) {
    pending_network_event_order_.push_back(event.id);
  }

  while (pending_network_events_.size() > kMaxPendingNetworkEvents &&
         !pending_network_event_order_.empty()) {
    const auto oldest_id = pending_network_event_order_.front();
    pending_network_event_order_.pop_front();
    pending_network_events_.erase(oldest_id);
  }
}

WebviewNetworkCaptureStartResult Webview::StartNetworkCapture() {
  if (!IsValid()) {
    return {false, "WebView2 instance is not valid."};
  }

  network_capture_enabled_ = true;
  if (FAILED(webview_->CallDevToolsProtocolMethod(L"Network.enable", L"{}",
                                                  nullptr))) {
    return FailNetworkCaptureStart("WebView2 CDP Network.enable failed.");
  }

  if (!network_response_received_receiver_) {
    if (FAILED(webview_->GetDevToolsProtocolEventReceiver(
            L"Network.responseReceived",
            &network_response_received_receiver_)) ||
        !network_response_received_receiver_) {
      return FailNetworkCaptureStart(
          "WebView2 CDP receiver attach failed for Network.responseReceived.");
    }
    if (FAILED(network_response_received_receiver_
                   ->add_DevToolsProtocolEventReceived(
                       Callback<
                           ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
                           [this](
                               ICoreWebView2* sender,
                               ICoreWebView2DevToolsProtocolEventReceivedEventArgs*
                                   args) -> HRESULT {
                             wil::unique_cotaskmem_string json_args;
                             if (args->get_ParameterObjectAsJson(&json_args) ==
                                 S_OK) {
                               HandleNetworkResponseReceived(
                                   util::Utf8FromUtf16(json_args.get()));
                             }
                             return S_OK;
                           })
                           .Get(),
                       &event_registrations_
                            .network_response_received_token_))) {
      return FailNetworkCaptureStart(
          "WebView2 CDP event subscription failed for Network.responseReceived.");
    }
    event_registrations_.has_network_response_received_token_ = true;
  }

  if (!network_loading_finished_receiver_) {
    if (FAILED(webview_->GetDevToolsProtocolEventReceiver(
            L"Network.loadingFinished", &network_loading_finished_receiver_)) ||
        !network_loading_finished_receiver_) {
      return FailNetworkCaptureStart(
          "WebView2 CDP receiver attach failed for Network.loadingFinished.");
    }
    if (FAILED(network_loading_finished_receiver_
                   ->add_DevToolsProtocolEventReceived(
                       Callback<
                           ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
                           [this](
                               ICoreWebView2* sender,
                               ICoreWebView2DevToolsProtocolEventReceivedEventArgs*
                                   args) -> HRESULT {
                             wil::unique_cotaskmem_string json_args;
                             if (args->get_ParameterObjectAsJson(&json_args) ==
                                 S_OK) {
                               HandleNetworkLoadingFinished(
                                   util::Utf8FromUtf16(json_args.get()));
                             }
                             return S_OK;
                           })
                           .Get(),
                       &event_registrations_
                            .network_loading_finished_token_))) {
      return FailNetworkCaptureStart(
          "WebView2 CDP event subscription failed for Network.loadingFinished.");
    }
    event_registrations_.has_network_loading_finished_token_ = true;
  }

  if (!network_websocket_frame_received_receiver_) {
    if (FAILED(webview_->GetDevToolsProtocolEventReceiver(
            L"Network.webSocketFrameReceived",
            &network_websocket_frame_received_receiver_)) ||
        !network_websocket_frame_received_receiver_) {
      return FailNetworkCaptureStart(
          "WebView2 CDP receiver attach failed for "
          "Network.webSocketFrameReceived.");
    }
    if (FAILED(network_websocket_frame_received_receiver_
                   ->add_DevToolsProtocolEventReceived(
                       Callback<
                           ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
                           [this](
                               ICoreWebView2* sender,
                               ICoreWebView2DevToolsProtocolEventReceivedEventArgs*
                                   args) -> HRESULT {
                             wil::unique_cotaskmem_string json_args;
                             if (args->get_ParameterObjectAsJson(&json_args) ==
                                 S_OK) {
                               HandleNetworkWebSocketFrameReceived(
                                   util::Utf8FromUtf16(json_args.get()));
                             }
                             return S_OK;
                           })
                           .Get(),
                       &event_registrations_
                            .network_websocket_frame_received_token_))) {
      return FailNetworkCaptureStart(
          "WebView2 CDP event subscription failed for "
          "Network.webSocketFrameReceived.");
    }
    event_registrations_.has_network_websocket_frame_received_token_ = true;
  }

  return {true, ""};
}

bool Webview::StopNetworkCapture() {
  const bool was_valid = IsValid();
  CleanupNetworkCapture();
  if (!was_valid) {
    return false;
  }
  return true;
}

void Webview::SetPopupWindowPolicy(WebviewPopupWindowPolicy policy) {
  popup_window_policy_ = policy;
}

bool Webview::SetUserAgent(const std::string& user_agent) {
  if (settings2_) {
    return settings2_->put_UserAgent(util::Utf16FromUtf8(user_agent).c_str()) ==
           S_OK;
  }
  return false;
}

bool Webview::SetBackgroundColor(int32_t color) {
  if (!IsValid()) {
    return false;
  }

  COREWEBVIEW2_COLOR webview_color;
  ConvertColor(webview_color, color);

  // Semi-transparent backgrounds are not supported.
  // Valid alpha values are 0 or 255.
  if (webview_color.A > 0) {
    webview_color.A = 0xFF;
  }

  return webview_controller_->put_DefaultBackgroundColor(webview_color) == S_OK;
}

bool Webview::SetZoomFactor(double factor) {
  if (!IsValid()) {
    return false;
  }
  return webview_controller_->put_ZoomFactor(factor) == S_OK;
}

void Webview::SetCursorPos(double x, double y) {
  if (!IsValid()) {
    return;
  }

  POINT point;
  point.x = static_cast<LONG>(x * scale_factor_);
  point.y = static_cast<LONG>(y * scale_factor_);
  last_cursor_pos_ = point;

  // https://docs.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2?view=webview2-1.0.774.44
  composition_controller_->SendMouseInput(
      COREWEBVIEW2_MOUSE_EVENT_KIND::COREWEBVIEW2_MOUSE_EVENT_KIND_MOVE,
      virtual_keys_.state(), 0, point);
}

void Webview::SetPointerUpdate(int32_t pointer,
                               WebviewPointerEventKind eventKind, double x,
                               double y, double size, double pressure) {
  if (!IsValid()) {
    return;
  }

  COREWEBVIEW2_POINTER_EVENT_KIND event =
      COREWEBVIEW2_POINTER_EVENT_KIND_UPDATE;
  UINT32 pointerFlags = POINTER_FLAG_NONE;
  switch (eventKind) {
    case WebviewPointerEventKind::Activate:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_ACTIVATE;
      break;
    case WebviewPointerEventKind::Down:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_DOWN;
      pointerFlags =
          POINTER_FLAG_DOWN | POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT;
      break;
    case WebviewPointerEventKind::Enter:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_ENTER;
      break;
    case WebviewPointerEventKind::Leave:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_LEAVE;
      break;
    case WebviewPointerEventKind::Up:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_UP;
      pointerFlags = POINTER_FLAG_UP;
      break;
    case WebviewPointerEventKind::Update:
      event = COREWEBVIEW2_POINTER_EVENT_KIND_UPDATE;
      pointerFlags =
          POINTER_FLAG_UPDATE | POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT;
      break;
  }

  POINT point;
  point.x = static_cast<LONG>(x * scale_factor_);
  point.y = static_cast<LONG>(y * scale_factor_);

  RECT rect;
  rect.left = point.x - 2;
  rect.right = point.x + 2;
  rect.top = point.y - 2;
  rect.bottom = point.y + 2;

  host_->CreateWebViewPointerInfo(
      [this, pointer, event, pointerFlags, point, rect, pressure](
          wil::com_ptr<ICoreWebView2PointerInfo> pointerInfo,
          std::unique_ptr<WebviewCreationError> error) {
        if (pointerInfo) {
          ICoreWebView2PointerInfo* pInfo = pointerInfo.get();
          pInfo->put_PointerId(pointer);
          pInfo->put_PointerKind(PT_TOUCH);
          pInfo->put_PointerFlags(pointerFlags);
          pInfo->put_TouchFlags(TOUCH_FLAG_NONE);
          pInfo->put_TouchMask(TOUCH_MASK_CONTACTAREA | TOUCH_MASK_PRESSURE);
          pInfo->put_TouchPressure(
              std::clamp((UINT32)(pressure == 0.0 ? 1024 : 1024 * pressure),
                         (UINT32)0, (UINT32)1024));
          pInfo->put_PixelLocationRaw(point);
          pInfo->put_TouchContactRaw(rect);
          composition_controller_->SendPointerInput(event, pInfo);
        }
      });
}

void Webview::SetPointerButtonState(WebviewPointerButton button, bool is_down) {
  if (!IsValid()) {
    return;
  }

  COREWEBVIEW2_MOUSE_EVENT_KIND kind;
  switch (button) {
    case WebviewPointerButton::Primary:
      virtual_keys_.set_isLeftButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_LEFT_BUTTON_DOWN
                     : COREWEBVIEW2_MOUSE_EVENT_KIND_LEFT_BUTTON_UP;
      break;
    case WebviewPointerButton::Secondary:
      virtual_keys_.set_isRightButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_RIGHT_BUTTON_DOWN
                     : COREWEBVIEW2_MOUSE_EVENT_KIND_RIGHT_BUTTON_UP;
      break;
    case WebviewPointerButton::Tertiary:
      virtual_keys_.set_isMiddleButtonDown(is_down);
      kind = is_down ? COREWEBVIEW2_MOUSE_EVENT_KIND_MIDDLE_BUTTON_DOWN
                     : COREWEBVIEW2_MOUSE_EVENT_KIND_MIDDLE_BUTTON_UP;
      break;
    default:
      kind = static_cast<COREWEBVIEW2_MOUSE_EVENT_KIND>(0);
  }

  composition_controller_->SendMouseInput(kind, virtual_keys_.state(), 0,
                                          last_cursor_pos_);
}

void Webview::SendScroll(double delta, bool horizontal) {
  // delta * 6 gives me a multiple of WHEEL_DELTA (120)
  constexpr auto kScrollMultiplier = 6;

  auto offset = static_cast<short>(delta * kScrollMultiplier);

  POINT point;
  point.x = 0;
  point.y = 0;

  if (horizontal) {
    composition_controller_->SendMouseInput(
        COREWEBVIEW2_MOUSE_EVENT_KIND_HORIZONTAL_WHEEL, virtual_keys_.state(),
        offset, point);
  } else {
    composition_controller_->SendMouseInput(COREWEBVIEW2_MOUSE_EVENT_KIND_WHEEL,
                                            virtual_keys_.state(), offset,
                                            point);
  }
}

void Webview::SetScrollDelta(double delta_x, double delta_y) {
  if (!IsValid()) {
    return;
  }

  if (delta_x != 0.0) {
    SendScroll(delta_x, true);
  }
  if (delta_y != 0.0) {
    SendScroll(delta_y, false);
  }
}

void Webview::LoadUrl(const std::string& url) {
  if (IsValid()) {
    webview_->Navigate(util::Utf16FromUtf8(url).c_str());
  }
}

void Webview::LoadStringContent(const std::string& content) {
  if (IsValid()) {
    webview_->NavigateToString(util::Utf16FromUtf8(content).c_str());
  }
}

bool Webview::Stop() {
  if (!IsValid()) {
    return false;
  }
  return SUCCEEDED(webview_->CallDevToolsProtocolMethod(L"Page.stopLoading",
                                                        L"{}", nullptr));
}

bool Webview::Reload() {
  if (!IsValid()) {
    return false;
  }
  return SUCCEEDED(webview_->Reload());
}

bool Webview::GoBack() {
  if (!IsValid()) {
    return false;
  }
  return SUCCEEDED(webview_->GoBack());
}

bool Webview::GoForward() {
  if (!IsValid()) {
    return false;
  }
  return SUCCEEDED(webview_->GoForward());
}

void Webview::AddScriptToExecuteOnDocumentCreated(
    const std::string& script,
    AddScriptToExecuteOnDocumentCreatedCallback callback) {
  if (IsValid()) {
    if (SUCCEEDED(webview_->AddScriptToExecuteOnDocumentCreated(
            util::Utf16FromUtf8(script).c_str(),
            Callback<
                ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(
                [callback](HRESULT result, LPCWSTR wsid) -> HRESULT {
                  std::string sid = util::Utf8FromUtf16(wsid);
                  callback(SUCCEEDED(result), sid);
                  return S_OK;
                })
                .Get()))) {
      return;
    }
  }

  callback(false, std::string());
}

void Webview::RemoveScriptToExecuteOnDocumentCreated(
    const std::string& script_id) {
  if (IsValid()) {
    webview_->RemoveScriptToExecuteOnDocumentCreated(
        util::Utf16FromUtf8(script_id).c_str());
  }
}

void Webview::ExecuteScript(const std::string& script,
                            ScriptExecutedCallback callback) {
  if (IsValid()) {
    if (SUCCEEDED(webview_->ExecuteScript(
            util::Utf16FromUtf8(script).c_str(),
            Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
                [callback](HRESULT result, LPCWSTR json_result_object) {
                  callback(SUCCEEDED(result),
                           util::Utf8FromUtf16(json_result_object));
                  return S_OK;
                })
                .Get()))) {
      return;
    }
  }

  callback(false, std::string());
}

bool Webview::PostWebMessage(const std::string& json) {
  if (!IsValid()) {
    return false;
  }
  return webview_->PostWebMessageAsJson(util::Utf16FromUtf8(json).c_str()) ==
         S_OK;
}

bool Webview::Suspend() {
  if (!IsValid()) {
    return false;
  }

  wil::com_ptr<ICoreWebView2_3> webview;
  webview = webview_.query<ICoreWebView2_3>();
  if (!webview) {
    return false;
  }

  webview_controller_->put_IsVisible(false);
  return webview->TrySuspend(
             Callback<ICoreWebView2TrySuspendCompletedHandler>(
                 [](HRESULT error_code, BOOL is_successful) -> HRESULT {
                   return S_OK;
                 })
                 .Get()) == S_OK;
}

bool Webview::Resume() {
  if (!IsValid()) {
    return false;
  }

  wil::com_ptr<ICoreWebView2_3> webview;
  webview = webview_.query<ICoreWebView2_3>();
  if (!webview) {
    return false;
  }
  return webview->Resume() == S_OK &&
         webview_controller_->put_IsVisible(true) == S_OK;
}

bool Webview::SetVirtualHostNameMapping(
    const std::string& hostName, const std::string& path,
    WebviewHostResourceAccessKind accessKind) {
  if (!IsValid()) {
    return false;
  }

  wil::com_ptr<ICoreWebView2_3> webview;
  webview = webview_.query<ICoreWebView2_3>();
  if (!webview) {
    return false;
  }

  COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND accessKindIntValue =
      COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY;
  switch (accessKind) {
    case WebviewHostResourceAccessKind::Allow:
      accessKindIntValue = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW;
      break;
    case WebviewHostResourceAccessKind::DenyCors:
      accessKindIntValue = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS;
      break;
    case WebviewHostResourceAccessKind::Deny:
      accessKindIntValue = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY;
      break;
  }

  return webview->SetVirtualHostNameToFolderMapping(
      util::Utf16FromUtf8(hostName).c_str(), util::Utf16FromUtf8(path).c_str(),
      accessKindIntValue);
}

bool Webview::ClearVirtualHostNameMapping(const std::string& hostName) {
  if (!IsValid()) {
    return false;
  }

  wil::com_ptr<ICoreWebView2_3> webview;
  webview = webview_.query<ICoreWebView2_3>();
  if (!webview) {
    return false;
  }

  return webview->ClearVirtualHostNameToFolderMapping(
      util::Utf16FromUtf8(hostName).c_str());
}
