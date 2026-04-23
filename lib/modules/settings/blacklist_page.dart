import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/user_provider.dart';
import '../../service/api/collection_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_button.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import 'settings_strings.dart';

class BlacklistPage extends ConsumerStatefulWidget {
  const BlacklistPage({super.key});

  @override
  ConsumerState<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends ConsumerState<BlacklistPage> {
  List<Map<String, dynamic>> _blacklist = [];
  bool _isLoading = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    setState(() => _isLoading = true);
    try {
      final blacklist = await SettingsApi.instance.getBlacklist();
      if (!mounted) {
        return;
      }
      setState(() => _blacklist = blacklist);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _blacklist = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFromBlacklist(String uid) async {
    final strings = _strings;
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      _showSnackBar(strings.userIdCannotBeEmpty, isError: true);
      return;
    }

    try {
      await SettingsApi.instance.removeBlacklist(normalizedUid);
      await ref.read(friendListProvider.notifier).refresh();
      await _loadBlacklist();
      _showSnackBar(strings.removedFromBlacklist);
    } catch (error) {
      _showSnackBar(strings.operationFailed(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.blacklistPageTitle)),
        body: WKLoadingView(message: strings.loading),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.blacklistPageTitle)),
      body: _blacklist.isEmpty
          ? WKEmptyView(
              icon: Icons.block_outlined,
              message: strings.blacklistEmpty,
              subMessage: strings.blacklistEmptyHint,
            )
          : RefreshIndicator(
              onRefresh: _loadBlacklist,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.md,
                  WKSpace.xl,
                ),
                itemCount: _blacklist.length,
                separatorBuilder: (_, _) => const SizedBox(height: WKSpace.sm),
                itemBuilder: (context, index) {
                  final user = _blacklist[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: WKColors.surface,
                      borderRadius: BorderRadius.circular(WKRadius.xl),
                      border: Border.all(color: WKColors.outline),
                      boxShadow: WKShadows.soft,
                    ),
                    child: ListTile(
                      leading: WKAvatar(
                        url: user['avatar']?.toString(),
                        name: user['name']?.toString() ?? 'U',
                        size: 44,
                      ),
                      title: Text(
                        user['name']?.toString() ?? strings.unknownUser,
                      ),
                      subtitle: Text(user['uid']?.toString() ?? ''),
                      trailing: WKTextButton(
                        text: strings.remove,
                        textColor: WKColors.danger,
                        onPressed: () =>
                            _removeFromBlacklist(user['uid']?.toString() ?? ''),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }
}
