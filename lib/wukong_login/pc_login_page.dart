import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modules/settings/settings_strings.dart';
import '../service/api/common_api.dart';
import '../widgets/wk_colors.dart';
import '../widgets/wk_reference_assets.dart';
import '../widgets/wk_sub_page_scaffold.dart';
import '../wukong_scan/scan_page.dart';
import 'pc_login_management_page.dart';
import 'pc_login_service.dart';

class PCLoginPage extends StatefulWidget {
  const PCLoginPage({
    super.key,
    this.onAuthCodeReceived,
    this.onRefresh,
    this.service,
    this.loadWebLoginUrl,
    this.onOpenScan,
    this.onOpenManagement,
  });

  final void Function(String authCode)? onAuthCodeReceived;
  final VoidCallback? onRefresh;
  final PCLoginService? service;
  final Future<String> Function()? loadWebLoginUrl;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenManagement;

  @override
  State<PCLoginPage> createState() => _PCLoginPageState();
}

class _PCLoginPageState extends State<PCLoginPage> {
  PCLoginService? _ownedService;
  String _webLoginUrl = '';

  PCLoginService get _service =>
      widget.service ?? (_ownedService ??= PCLoginService());
  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    if (widget.onAuthCodeReceived != null) {
      unawaited(_bootstrapLegacyAuthCodeFlow());
    }
    unawaited(_loadWebLoginUrl());
  }

  @override
  void dispose() {
    final service = widget.service ?? _ownedService;
    service?.onLoginStatusChanged = null;
    service?.stopPollingLoginStatus();
    super.dispose();
  }

  Future<void> _bootstrapLegacyAuthCodeFlow() async {
    try {
      _service.onLoginStatusChanged = (success, authCode) {
        if (!success) {
          return;
        }
        final normalizedAuthCode = (authCode ?? '').trim();
        if (normalizedAuthCode.isNotEmpty) {
          widget.onAuthCodeReceived?.call(normalizedAuthCode);
        }
        widget.onRefresh?.call();
      };
      final scene = await _service.requestPCLoginQRCode();
      if (!mounted) {
        return;
      }
      _service.startPollingLoginStatus(scene);
      widget.onRefresh?.call();
    } catch (_) {
      // Keep the guide page usable even if the legacy polling bridge cannot
      // initialize in the current environment.
    }
  }

  Future<void> _loadWebLoginUrl() async {
    try {
      final loadWebLoginUrl = widget.loadWebLoginUrl;
      final webLoginUrl = loadWebLoginUrl != null
          ? await loadWebLoginUrl()
          : (await CommonApi.instance.getRuntimeCapabilities()).webLoginUrl;
      if (!mounted) {
        return;
      }
      setState(() => _webLoginUrl = webLoginUrl.trim());
    } catch (_) {
      // Keep the guide visible even if runtime capability probing fails.
    }
  }

  Future<void> _copyUrl() async {
    final text = _webLoginUrl.trim();
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_strings.webLoginAddressCopied)),
    );
  }

  void _openScanPage() {
    final onOpenScan = widget.onOpenScan;
    if (onOpenScan != null) {
      onOpenScan();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScanPage()));
  }

  void _openManagementPage() {
    final onOpenManagement = widget.onOpenManagement;
    if (onOpenManagement != null) {
      onOpenManagement();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PCLoginManagementPage(onRefresh: widget.onRefresh),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final displayUrl = _webLoginUrl.trim().isEmpty
        ? strings.loadingWebLoginAddress
        : _webLoginUrl.trim();

    return KeyedSubtree(
      key: const ValueKey<String>('pc-login-page'),
      child: WKSubPageScaffold(
        title: strings.pcLoginPageTitle,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: WKReferenceAssets.image(
                      WKReferenceAssets.webLogin,
                      width: 34,
                      height: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.pcLoginGuideDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: WKColors.colorDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    displayUrl,
                    key: const ValueKey<String>('pc-login-web-url'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: WKColors.color999,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _GuideActionButton(
              key: const ValueKey<String>('pc-login-copy-url'),
              title: strings.copyAddress,
              subtitle: strings.copyWebLoginUrl,
              icon: Icons.copy_rounded,
              onTap: _copyUrl,
            ),
            const SizedBox(height: 12),
            _GuideActionButton(
              key: const ValueKey<String>('pc-login-open-scan'),
              title: strings.scanQrCode,
              subtitle: strings.useMobileScanToConfirmLogin,
              icon: Icons.qr_code_scanner_rounded,
              onTap: _openScanPage,
            ),
            const SizedBox(height: 12),
            _GuideActionButton(
              key: const ValueKey<String>('pc-login-open-management'),
              title: strings.pcLoginStatus,
              subtitle: strings.openManagementControls,
              icon: Icons.computer_rounded,
              onTap: _openManagementPage,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideActionButton extends StatelessWidget {
  const _GuideActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: WKColors.brand500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: WKColors.color999,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
