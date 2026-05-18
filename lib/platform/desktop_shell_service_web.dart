import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'desktop_shell_contract.dart';

DesktopShellService createPlatformDesktopShellService() =>
    WebDesktopShellService();

class WebDesktopShellService extends DesktopShellService {
  WebDesktopShellService();

  String? _baseTitle;

  @override
  Future<void> minimizeToTray() async {}

  @override
  Future<void> setBadgeCount(int count) async {
    _baseTitle ??= web.document.title;
    final normalizedCount = count < 0 ? 0 : count;
    final title = _baseTitle ?? '';
    web.document.title = normalizedCount > 0
        ? '($normalizedCount) $title'
        : title;

    final navigator = web.window.navigator;
    try {
      if (normalizedCount > 0) {
        await navigator.setAppBadge(normalizedCount).toDart;
      } else {
        await navigator.clearAppBadge().toDart;
      }
    } catch (_) {
      // The Badging API is optional and may be blocked by the browser.
    }
  }

  @override
  Future<void> flashTaskbar() async {
    _baseTitle ??= web.document.title;
    final title = _baseTitle ?? '';
    web.document.title = title.startsWith('[新消息]') ? title : '[新消息] $title';
  }
}
