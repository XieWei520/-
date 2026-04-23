import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/models/user.dart';
import '../service/api/auth_api.dart';
import '../service/api/openapi_api.dart';
import 'openapi_webview_bridge.dart';

class ScanWebviewPage extends StatefulWidget {
  ScanWebviewPage({
    super.key,
    required this.initialUrl,
    OpenApiApi? openApiApi,
    Future<UserInfo?> Function()? loadCurrentUser,
    this.requestAuthorization,
  }) : openApiApi = openApiApi ?? OpenApiApi.instance,
       loadCurrentUser = loadCurrentUser ?? _defaultCurrentUserLoader;

  final String initialUrl;
  final OpenApiApi openApiApi;
  final Future<UserInfo?> Function() loadCurrentUser;
  final Future<bool> Function(
    BuildContext context,
    OpenApiAuthorizationPrompt prompt,
  )?
  requestAuthorization;

  @override
  State<ScanWebviewPage> createState() => _ScanWebviewPageState();

  static Future<UserInfo?> _defaultCurrentUserLoader() async {
    try {
      return await AuthApi.instance.getCurrentUser();
    } catch (_) {
      return null;
    }
  }
}

class _ScanWebviewPageState extends State<ScanWebviewPage> {
  late final WebViewController _controller;
  late final Uri? _uri;
  late final OpenApiWebViewBridgeController _openApiBridgeController;
  bool _isLoading = true;
  String _title = 'Web';

  @override
  void initState() {
    super.initState();
    _uri = Uri.tryParse(widget.initialUrl);
    _openApiBridgeController = OpenApiWebViewBridgeController(
      fetchAppInfo: widget.openApiApi.getAppInfo,
      fetchAuthCode: widget.openApiApi.getAuthCode,
      loadCurrentUser: widget.loadCurrentUser,
      requestAuthorization: _requestOpenApiAuthorization,
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        OpenApiWebViewBridgeController.channelName,
        onMessageReceived: (message) {
          unawaited(_handleBridgeMessage(message.message));
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) async {
            await _injectOpenApiBridge();
            final title = await _controller.getTitle();
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
              _title = (title?.trim().isNotEmpty ?? false)
                  ? title!.trim()
                  : 'Web';
            });
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      );
    if (_uri != null) {
      _controller.loadRequest(_uri);
    }
  }

  Future<void> _injectOpenApiBridge() async {
    try {
      await _controller.runJavaScript(
        OpenApiWebViewBridgeController.bootstrapScript,
      );
    } catch (_) {}
  }

  Future<void> _handleBridgeMessage(String rawMessage) async {
    final result = await _openApiBridgeController.handleRawMessage(rawMessage);
    if (!result.handled || result.callback == null) {
      return;
    }
    try {
      await _controller.runJavaScript(result.callback!.toJavaScript());
    } catch (_) {}
  }

  Future<bool> _requestOpenApiAuthorization(
    OpenApiAuthorizationPrompt prompt,
  ) async {
    final override = widget.requestAuthorization;
    if (override != null) {
      return override(context, prompt);
    }

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OpenApiAuthorizationSheet(
        prompt: prompt,
        sourceHost: _uri?.host.trim() ?? '',
      ),
    );
    return approved ?? false;
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.initialUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _openExternally() async {
    final uri = _uri;
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open link')));
    }
  }

  Future<void> _reload() => _controller.reload();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            PopupMenuButton<_ScanWebviewAction>(
              onSelected: (action) {
                switch (action) {
                  case _ScanWebviewAction.copy:
                    _copyUrl();
                  case _ScanWebviewAction.refresh:
                    _reload();
                  case _ScanWebviewAction.external:
                    _openExternally();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ScanWebviewAction.copy,
                  child: Text('Copy link'),
                ),
                PopupMenuItem(
                  value: _ScanWebviewAction.refresh,
                  child: Text('Refresh'),
                ),
                PopupMenuItem(
                  value: _ScanWebviewAction.external,
                  child: Text('Open in browser'),
                ),
              ],
            ),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: _uri == null
            ? const Center(child: Text('Invalid link'))
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

enum _ScanWebviewAction { copy, refresh, external }

class _OpenApiAuthorizationSheet extends StatelessWidget {
  const _OpenApiAuthorizationSheet({
    required this.prompt,
    required this.sourceHost,
  });

  final OpenApiAuthorizationPrompt prompt;
  final String sourceHost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = prompt.currentUser;
    final userName = _displayName(user);
    final hostLabel = sourceHost.isEmpty ? 'Embedded web page' : sourceHost;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          top: 20,
          right: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NetworkAvatar(
                  imageUrl: prompt.appInfo.appLogo,
                  label: prompt.appInfo.appName,
                  radius: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authorize app access',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prompt.appInfo.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '$hostLabel is requesting an OpenAPI authorization code for your account.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _NetworkAvatar(
                    imageUrl: user?.avatar,
                    label: userName,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.uid.trim().isNotEmpty == true
                              ? 'UID: ${user!.uid}'
                              : 'Current signed-in account',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Allow'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(UserInfo? user) {
    final name = user?.name?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final username = user?.username?.trim() ?? '';
    if (username.isNotEmpty) {
      return username;
    }
    final uid = user?.uid.trim() ?? '';
    if (uid.isNotEmpty) {
      return uid;
    }
    return 'Current account';
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({
    required this.imageUrl,
    required this.label,
    required this.radius,
  });

  final String? imageUrl;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim() ?? '';
    if (normalizedUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          normalizedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final trimmed = label.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return CircleAvatar(radius: radius, child: Text(initial.toUpperCase()));
  }
}
