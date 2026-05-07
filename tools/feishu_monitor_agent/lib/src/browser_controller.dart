import 'dart:async';
import 'dart:convert';

import 'package:puppeteer/puppeteer.dart' as pp;

import 'agent_models.dart';
import 'browser_profile.dart';
import 'feishu_web_adapter.dart';

const _feishuMessengerUrl = 'https://www.feishu.cn/messenger/';

abstract class BrowserControllerLike {
  Future<BrowserLoginStatus> openLogin({required bool keepOpen});

  Future<BrowserLoginStatus> checkStatus();

  Future<List<String>> listChats();

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
  bool _attachedToExistingBrowser = false;

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
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding',
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
  Future<List<String>> listChats() async {
    try {
      final page = await _openMessenger(headless: true);
      final status = await _classifyPage(page);
      if (status == BrowserLoginStatus.loginRequired ||
          status == BrowserLoginStatus.browserError) {
        await close();
        return const <String>[];
      }
      final chats = await _collectVisibleChatsByScrolling(page);
      await close();
      return chats;
    } catch (_) {
      await close();
      return const <String>[];
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
      await _scrollActiveChatToBottom(page);
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
    final pages = await browser.pages;
    final page =
        _selectReusableMessengerPage(pages) ??
        (headless || pages.isEmpty ? await browser.newPage() : pages.last);
    _page = page;
    page.defaultNavigationTimeout = navigationTimeout;
    if (!_isMessengerPage(page)) {
      await page.goto(
        messengerUrl,
        timeout: navigationTimeout,
        wait: pp.Until.domContentLoaded,
      );
    } else if (!headless) {
      await page.bringToFront();
    }
    await Future<void>.delayed(settleDelay);
    return page;
  }

  pp.Page? _selectReusableMessengerPage(List<pp.Page> pages) {
    for (final page in pages.reversed) {
      if (_isMessengerPage(page) && !_isDegradedMessengerPage(page)) {
        return page;
      }
    }
    for (final page in pages.reversed) {
      if (_isMessengerPage(page)) {
        return page;
      }
    }
    return null;
  }

  bool _isMessengerPage(pp.Page page) {
    final url = page.url ?? '';
    return url.contains('/messenger');
  }

  bool _isDegradedMessengerPage(pp.Page page) {
    final url = page.url ?? '';
    return url.contains('/messenger/degraded');
  }

  Future<pp.Browser> _ensureBrowser(PuppeteerLaunchConfig config) async {
    final existing = _browser;
    if (existing != null) {
      return existing;
    }
    if (config.headless) {
      final attached = await _tryAttachExistingBrowser();
      if (attached != null) {
        _browser = attached;
        _attachedToExistingBrowser = true;
        return attached;
      }
    }
    final browser = await pp.puppeteer.launch(
      headless: config.headless,
      userDataDir: config.userDataDir,
      args: config.args,
      timeout: launchTimeout,
      waitForInitialPage: false,
    );
    _browser = browser;
    _attachedToExistingBrowser = false;
    if (!config.headless) {
      await _saveBrowserEndpoint(browser);
    }
    return browser;
  }

  Future<pp.Browser?> _tryAttachExistingBrowser() async {
    try {
      final endpointFile = paths.browserEndpointFile;
      if (!await endpointFile.exists()) {
        return null;
      }
      final decoded =
          jsonDecode(await endpointFile.readAsString()) as Map<String, dynamic>;
      final wsEndpoint = decoded['ws_endpoint']?.toString().trim() ?? '';
      if (wsEndpoint.isEmpty) {
        return null;
      }
      return await pp.puppeteer.connect(browserWsEndpoint: wsEndpoint);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveBrowserEndpoint(pp.Browser browser) async {
    try {
      final endpointFile = paths.browserEndpointFile;
      await endpointFile.parent.create(recursive: true);
      await endpointFile.writeAsString(
        jsonEncode(<String, String>{
          'ws_endpoint': browser.wsEndpoint,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // Endpoint persistence is a convenience for later status checks.
    }
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

  Future<void> _scrollActiveChatToBottom(pp.Page page) async {
    await page.evaluate<void>(r'''() => {
      const candidates = Array.from(document.querySelectorAll(
        '.scroller, [class*="scroller"], .messageList, [class*="messageList"], [class*="message-list"]'
      ));
      const visible = (node) => {
        const style = window.getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return style.visibility !== 'hidden' &&
          style.display !== 'none' &&
          rect.width > 0 &&
          rect.height > 0;
      };
      const containers = candidates
        .filter((node) => {
          if (!visible(node) || node.scrollHeight <= node.clientHeight) return false;
          const rect = node.getBoundingClientRect();
          return rect.left > Math.max(420, window.innerWidth * 0.35) &&
            rect.height > 240 &&
            rect.width > 280;
        })
        .sort((a, b) => {
          const score = (node) => {
            const rect = node.getBoundingClientRect();
            const className = (node.className || '').toString();
            const messageScore = /message|chat/i.test(className) ? 4000 : 0;
            const rightScore = Math.max(0, rect.left);
            const scrollScore = Math.min(4000, node.scrollHeight - node.clientHeight);
            return messageScore + rightScore + scrollScore;
          };
          return score(b) - score(a);
        });
      const container = containers[0];
      if (!container) return;
      container.scrollTop = container.scrollHeight;
      container.dispatchEvent(new WheelEvent('wheel', {
        deltaY: 20000,
        bubbles: true,
        cancelable: true,
      }));
    }''');
  }

  Future<List<String>> _collectVisibleChatsByScrolling(pp.Page page) async {
    final raw = await page.evaluate<List<dynamic>>(r'''async () => {
      const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
      const waitForFeed = async () => {
        for (let attempt = 0; attempt < 30; attempt += 1) {
          const rows = Array.from(document.querySelectorAll('.a11y_feed_card_item, [class*="feed_card_item"]'))
            .filter((node) => {
              const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
              return text.length > 0;
            });
          if (rows.length > 0) return true;
          await sleep(500);
        }
        return false;
      };
      await waitForFeed();
      const visible = (node) => {
        const style = window.getComputedStyle(node);
        const rect = node.getBoundingClientRect();
        return style.visibility !== 'hidden' &&
          style.display !== 'none' &&
          rect.width > 0 &&
          rect.height > 0;
      };
      const normalize = (value) => (value || '').replace(/\s+/g, ' ').trim();
      const badText = (text) => {
        if (!text || text.length < 2 || text.length > 80) return true;
        const lower = text.toLowerCase();
        return lower.includes('搜索') ||
          lower.includes('快捷') ||
          lower.includes('消息') && text.length < 4 ||
          lower.includes('通讯录') ||
          lower.includes('云文档') ||
          lower.includes('工作台') ||
          lower.includes('日历') ||
          lower.includes('会议') ||
          lower.includes('设置');
      };
      const collect = (container) => {
        const feedRows = Array.from(container.querySelectorAll('.a11y_feed_card_item, [class*="feed_card_item"]'))
          .filter((node) => visible(node))
          .map((node) => normalize(node.innerText || node.textContent || ''))
          .filter((text) => !badText(text));
        if (feedRows.length > 0) {
          return feedRows;
        }
        const selectors = [
          '[role="listitem"]',
          '[role="treeitem"]',
          '[class*="chat"]',
          '[class*="session"]',
          '[class*="conversation"]',
          '[class*="item"]'
        ];
        const rows = [];
        const seenNode = new Set();
        const roots = [container];
        if (container !== document.body && container !== document.documentElement) {
          roots.push(document);
        }
        for (const root of roots) {
          for (const selector of selectors) {
            for (const node of Array.from(root.querySelectorAll(selector))) {
            if (seenNode.has(node) || !visible(node)) continue;
            seenNode.add(node);
            const rect = node.getBoundingClientRect();
            if (rect.width < 120 || rect.height < 18 || rect.height > 120) continue;
            const text = normalize(node.innerText || node.textContent || '');
            if (!badText(text)) rows.push(text);
            }
          }
        }
        return rows;
      };
      const containers = Array.from(document.querySelectorAll(
        '[role="list"], [role="tree"], [class*="list"], [class*="session"], [class*="chat"], [class*="conversation"], div'
      ))
        .filter((node) => {
          if (!visible(node) || node.scrollHeight <= node.clientHeight + 80) return false;
          const rect = node.getBoundingClientRect();
          if (rect.width < 180 || rect.width > 760 || rect.height < 240) return false;
          const leftScore = rect.left < Math.max(720, window.innerWidth * 0.65);
          return leftScore;
        })
        .sort((a, b) => {
          const ar = a.getBoundingClientRect();
          const br = b.getBoundingClientRect();
          const score = (node, rect) => {
            const className = (node.className || '').toString();
            const feedScore = className.includes('feed-main-list') || className.includes('lark_feedMainList') ? 6000 : 0;
            const widthScore = Math.max(0, 760 - Math.abs(rect.width - 320));
            const leftScore = Math.max(0, 1000 - rect.left);
            const scrollScore = Math.min(1800, node.scrollHeight - node.clientHeight);
            const textScore = (node.innerText || '').trim().length > 0 ? 800 : 0;
            return feedScore + textScore + widthScore * 3 + leftScore + scrollScore;
          };
          const as = score(a, ar);
          const bs = score(b, br);
          return bs - as;
        });
      const container = containers[0] || document.scrollingElement || document.body;
      await sleep(180);
      const result = new Set();
      let stableRounds = 0;
      let previousSize = 0;
      for (let round = 0; round < 80; round += 1) {
        for (const item of collect(container)) result.add(item);
        if (result.size === previousSize) {
          stableRounds += 1;
        } else {
          stableRounds = 0;
          previousSize = result.size;
        }
        const reachedBottom = (container.scrollTop + container.clientHeight) >= (container.scrollHeight - 8);
        if (reachedBottom || stableRounds >= 6) break;
        const before = container.scrollTop || 0;
        container.scrollTop = before + Math.max(180, Math.floor(container.clientHeight * 0.72));
        container.dispatchEvent(new WheelEvent('wheel', {deltaY: Math.max(180, Math.floor(container.clientHeight * 0.72)), bubbles: true}));
        await sleep(360);
        const after = container.scrollTop || 0;
        if (Math.abs(after - before) < 4) {
          stableRounds += 1;
        }
      }
      for (const item of collect(container)) result.add(item);
      return Array.from(result).slice(0, 1000);
    }''');
    final seen = <String>{};
    final chats = <String>[];
    for (final item in raw) {
      final name = FeishuChatNameNormalizer.normalize(item.toString());
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      chats.add(name);
    }
    return chats;
  }

  Future<List<_RawMessageRow>> _extractVisibleMessageRows(pp.Page page) async {
    final raw = await page.evaluate<List<dynamic>>(r'''() => {
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
        const normalize = (value) => (value || '').replace(/\s+/g, ' ').trim();
        const messageRows = Array.from(document.querySelectorAll(
          '.messageItem-wrapper[data-id], .js-message-item[id], [data-message-id]'
        ))
          .filter((node) => {
            if (!visible(node)) return false;
            const rect = node.getBoundingClientRect();
            if (rect.left < Math.max(420, window.innerWidth * 0.35)) return false;
            return rect.width > 120 && rect.height > 12;
          })
          .sort((a, b) => {
            const ar = a.getBoundingClientRect();
            const br = b.getBoundingClientRect();
            return (ar.top - br.top) || (ar.left - br.left);
          });
        const textSelectors = [
          '.message-text',
          '.message-content',
          '.message-content-container',
          '.richTextContainer',
          '.text-only',
          '[role="text-message"]',
          '[data-message-text]',
          '[class*="message_content"]',
          '[class*="message-content"]',
          '[class*="rich_text"]',
          '[class*="rich-text"]'
        ];
        for (const node of messageRows) {
          const id = node.getAttribute('data-id') ||
            node.getAttribute('data-message-id') ||
            node.id ||
            '';
          const rect = node.getBoundingClientRect();
          const key = id || `${rect.top}:${rect.left}`;
          if (seen.has(key)) continue;
          seen.add(key);
          let cleaned = '';
          for (const selector of textSelectors) {
            const children = Array.from(node.querySelectorAll(selector))
              .filter(visible)
              .map((child) => normalize(child.innerText || child.textContent || ''))
              .filter((text) => text.length >= 2);
            if (children.length > 0) {
              children.sort((a, b) => a.length - b.length);
              cleaned = children[0];
              break;
            }
          }
          if (!cleaned) {
            cleaned = normalize(node.innerText || node.textContent || '');
          }
          if (!cleaned) {
            continue;
          }
          rows.push({ id, text: cleaned });
        }
        if (rows.length > 0) {
          return rows.slice(-20);
        }
        const selectors = [
          '[data-testid*="message"]',
          '.message',
          '[class*="message"]'
        ];
        for (const selector of selectors) {
          for (const node of Array.from(document.querySelectorAll(selector))) {
            if (seen.has(node) || !visible(node)) continue;
            seen.add(node);
            const rect = node.getBoundingClientRect();
            if (rect.left < Math.max(420, window.innerWidth * 0.35)) continue;
            const cleaned = normalize(node.innerText || node.textContent || '');
            if (!cleaned) continue;
            rows.push({
              id: node.getAttribute('data-message-id') ||
                node.getAttribute('data-id') ||
                node.id ||
                '',
              text: cleaned,
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
      final content = FeishuMessageTextExtractor.extractFocusedMessage(
        row.text,
        chatName: route.sourceChatName,
      );
      if (content.isEmpty) {
        continue;
      }
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
          content: content,
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
    final attachedToExistingBrowser = _attachedToExistingBrowser;
    _attachedToExistingBrowser = false;
    final page = _page;
    _page = null;
    if (page != null && !attachedToExistingBrowser) {
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
        if (attachedToExistingBrowser) {
          // Keep the interactive browser alive. The puppeteer package can emit
          // late target-detached events during disconnect, so do not let those
          // events fail Agent CLI commands such as browser-status.
          try {
            browser.disconnect();
          } catch (_) {
            // Ignore detach/disconnect races from an already-running browser.
          }
        } else {
          await browser.close();
        }
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
