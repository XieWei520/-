import 'dart:async';

import 'package:puppeteer/puppeteer.dart' as pp;

import 'agent_models.dart';
import 'browser_profile.dart';
import 'feishu_web_adapter.dart';

const _feishuMessengerUrl = 'https://www.feishu.cn/messenger/';

abstract class BrowserControllerLike {
  Future<BrowserLoginStatus> openLogin({required bool keepOpen});

  Future<BrowserLoginStatus> checkStatus();

  Future<List<FeishuObservedMessage>> observeRoute({
    required AgentMonitorRoute route,
    required String observedAt,
  });

  Future<void> close();
}

class PuppeteerLaunchConfig {
  const PuppeteerLaunchConfig({
    required this.headless,
    required this.userDataDir,
    required this.args,
  });

  final bool headless;
  final String userDataDir;
  final List<String> args;
}

class PuppeteerBrowserController implements BrowserControllerLike {
  PuppeteerBrowserController(
    this.paths, {
    this.messengerUrl = _feishuMessengerUrl,
    this.launchTimeout = const Duration(seconds: 45),
    this.navigationTimeout = const Duration(seconds: 30),
    this.settleDelay = const Duration(seconds: 2),
  });

  final BrowserProfilePaths paths;
  final String messengerUrl;
  final Duration launchTimeout;
  final Duration navigationTimeout;
  final Duration settleDelay;

  pp.Browser? _browser;
  pp.Page? _page;

  static PuppeteerLaunchConfig buildLaunchConfig(
    BrowserProfilePaths paths, {
    required bool headless,
  }) {
    return PuppeteerLaunchConfig(
      headless: headless,
      userDataDir: paths.profileDir.path,
      args: const <String>[
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-dev-shm-usage',
        '--window-size=1280,900',
      ],
    );
  }

  @override
  Future<BrowserLoginStatus> openLogin({required bool keepOpen}) async {
    try {
      final page = await _openMessenger(headless: false);
      await page.bringToFront();
      final status = await _classifyPage(page);
      if (!keepOpen) {
        await close();
      }
      return status;
    } catch (_) {
      await close();
      return BrowserLoginStatus.browserError;
    }
  }

  @override
  Future<BrowserLoginStatus> checkStatus() async {
    try {
      final page = await _openMessenger(headless: true);
      final status = await _classifyPage(page);
      await close();
      return status;
    } catch (_) {
      await close();
      return BrowserLoginStatus.browserError;
    }
  }

  @override
  Future<List<FeishuObservedMessage>> observeRoute({
    required AgentMonitorRoute route,
    required String observedAt,
  }) async {
    try {
      final page = await _openMessenger(headless: true);
      final status = await _classifyPage(page);
      if (status == BrowserLoginStatus.loginRequired) {
        await close();
        return const <FeishuObservedMessage>[];
      }

      await _trySelectChat(page, route.sourceChatName);
      await Future<void>.delayed(settleDelay);
      final rows = await _extractVisibleMessageRows(page);
      await close();

      return _toObservedMessages(
        rows: rows,
        route: route,
        observedAt: observedAt,
      );
    } catch (_) {
      await close();
      return const <FeishuObservedMessage>[];
    }
  }

  Future<pp.Page> _openMessenger({required bool headless}) async {
    await paths.profileDir.create(recursive: true);
    final config = buildLaunchConfig(paths, headless: headless);
    final browser = await _ensureBrowser(config);
    final page = await browser.newPage();
    _page = page;
    page.defaultNavigationTimeout = navigationTimeout;
    await page.goto(
      messengerUrl,
      timeout: navigationTimeout,
      wait: pp.Until.domContentLoaded,
    );
    await Future<void>.delayed(settleDelay);
    return page;
  }

  Future<pp.Browser> _ensureBrowser(PuppeteerLaunchConfig config) async {
    final existing = _browser;
    if (existing != null) {
      return existing;
    }
    final browser = await pp.puppeteer.launch(
      headless: config.headless,
      userDataDir: config.userDataDir,
      args: config.args,
      timeout: launchTimeout,
    );
    _browser = browser;
    return browser;
  }

  Future<BrowserLoginStatus> _classifyPage(pp.Page page) async {
    final text = await page.evaluate<String>(
      '() => document.body ? document.body.innerText : ""',
    );
    return FeishuWebDomClassifier.classifyText(text);
  }

  Future<void> _trySelectChat(pp.Page page, String chatName) async {
    final target = chatName.trim();
    if (target.isEmpty) {
      return;
    }
    await page.evaluate<bool>(
      r'''(chatName) => {
        const candidates = Array.from(document.querySelectorAll(
          '[role="listitem"], [role="treeitem"], [class*="chat"], [class*="session"], [class*="item"], a, button, div'
        ));
        const visible = (node) => {
          const style = window.getComputedStyle(node);
          const rect = node.getBoundingClientRect();
          return style.visibility !== 'hidden' &&
            style.display !== 'none' &&
            rect.width > 0 &&
            rect.height > 0;
        };
        const match = candidates.find((node) => {
          const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
          return visible(node) && text && text.includes(chatName);
        });
        if (!match) {
          return false;
        }
        match.scrollIntoView({block: 'center', inline: 'nearest'});
        match.click();
        return true;
      }''',
      args: <String>[target],
    );
  }

  Future<List<_RawMessageRow>> _extractVisibleMessageRows(pp.Page page) async {
    final raw = await page.evaluate<List<dynamic>>(r'''() => {
        const selectors = [
          '[data-message-id]',
          '[data-testid*="message"]',
          '.message',
          '[class*="message"]'
        ];
        const seen = new Set();
        const rows = [];
        const visible = (node) => {
          const style = window.getComputedStyle(node);
          const rect = node.getBoundingClientRect();
          return style.visibility !== 'hidden' &&
            style.display !== 'none' &&
            rect.width > 0 &&
            rect.height > 0;
        };
        for (const selector of selectors) {
          for (const node of Array.from(document.querySelectorAll(selector))) {
            if (seen.has(node) || !visible(node)) {
              continue;
            }
            seen.add(node);
            const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
            if (!text) {
              continue;
            }
            rows.push({
              id: node.getAttribute('data-message-id') ||
                node.getAttribute('data-id') ||
                node.id ||
                '',
              text,
            });
          }
        }
        return rows.slice(-20);
      }''');
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => _RawMessageRow(
            rawId: item['id']?.toString() ?? '',
            text: item['text']?.toString() ?? '',
          ),
        )
        .where((row) => row.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<FeishuObservedMessage> _toObservedMessages({
    required List<_RawMessageRow> rows,
    required AgentMonitorRoute route,
    required String observedAt,
  }) {
    final messages = <FeishuObservedMessage>[];
    for (var index = 0; index < rows.length; index += 1) {
      final row = rows[index];
      final messageType = _messageTypeFor(row.text);
      if (messageType == 'link' && !route.includeLinks) {
        continue;
      }
      if (messageType == 'text' && !route.includeText) {
        continue;
      }
      messages.add(
        FeishuObservedMessage.fromRaw(
          routeId: route.routeId,
          sourceChatName: route.sourceChatName,
          rawId: row.rawId,
          messageType: messageType,
          content: row.text,
          observedAt: observedAt,
          domOrder: index,
        ),
      );
    }
    return messages;
  }

  String _messageTypeFor(String text) {
    final normalized = text.trim().toLowerCase();
    if (RegExp(r'https?://\S+').hasMatch(normalized)) {
      return 'link';
    }
    return 'text';
  }

  @override
  Future<void> close() async {
    final page = _page;
    _page = null;
    if (page != null) {
      try {
        await page.close();
      } catch (_) {
        // Page may already be gone when the browser has closed.
      }
    }
    final browser = _browser;
    _browser = null;
    if (browser != null) {
      try {
        await browser.close();
      } catch (_) {
        // Browser may already be closed by the user.
      }
    }
  }
}

class _RawMessageRow {
  const _RawMessageRow({required this.rawId, required this.text});

  final String rawId;
  final String text;
}
