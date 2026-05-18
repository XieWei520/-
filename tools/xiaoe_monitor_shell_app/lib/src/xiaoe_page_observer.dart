const String xiaoePageObserverScript = r'''
(() => {
  const key = '__wukongXiaoeMonitorObserver';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const notify = (reason) => post({
    type: 'xiaoe_monitor_page_changed',
    reason,
    observed_at: new Date().toISOString()
  });
  if (window[key]?.observer) {
    notify('observer_already_installed');
    return;
  }
  const root = document.body || document.documentElement;
  if (!root) {
    return;
  }
  const observer = new MutationObserver(() => notify('mutation'));
  observer.observe(root, { childList: true, subtree: true, characterData: true });
  window[key] = { observer };
  notify('observer_installed');
})();
''';

class XiaoePageObserverMessage {
  const XiaoePageObserverMessage({
    required this.type,
    required this.reason,
    required this.observedAt,
  });

  final String type;
  final String reason;
  final DateTime? observedAt;

  bool get isPageChanged => type == 'xiaoe_monitor_page_changed';

  factory XiaoePageObserverMessage.fromJson(Map<String, Object?> json) {
    return XiaoePageObserverMessage(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      observedAt: DateTime.tryParse((json['observed_at'] ?? '').toString()),
    );
  }
}
