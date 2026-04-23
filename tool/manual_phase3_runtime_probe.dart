import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/app/bootstrap/app_startup.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/group_api.dart';
import 'package:wukong_im_app/widgets/wk_theme.dart';
import 'package:wukong_im_app/wk_foundation/logging/app_logger.dart';
import 'package:wukong_im_app/wk_foundation/net/wk_http_client.dart';
import 'package:wukong_im_app/wk_foundation/runtime/app_environment.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';
import 'package:wukong_im_app/wukong_push/push_service.dart';
import 'package:wukong_im_app/wukong_scan/scan_result_page.dart';
import 'package:wukong_im_app/wukong_scan/scan_service.dart';
import 'package:wukong_im_app/wukong_uikit/group/all_members_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_scan_join_page.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

const String _fallbackProbeGroupNo = 'df24aeff95b447569deb766c21918552';
const String _syntheticProbeAuthCode = 'manual-probe-auth';
const String _probeTargetGroupDetail = 'group_detail';
const String _probeTargetAllMembers = 'all_members';
const String _probeTargetAllMembersSearch = 'all_members_search';
const String _probeTargetChatSearchEntry = 'chat_search_entry';
const String _probeTargetScanActive = 'scan_active';
const String _probeTargetScanRemoved = 'scan_removed';
const String _probeTargetScanInternalJoin = 'scan_internal_join';
const String _probeTargetGroupScanJoin = 'group_scan_join';
const String _probeTargetEnvVar = 'MANUAL_PHASE3_PROBE_TARGET';

typedef ManualPhase3ProbeLoader = Future<ManualPhase3ProbeSnapshot> Function();
typedef ManualPhase3ProbePageBuilder =
    Widget Function(ManualPhase3ProbeSnapshot snapshot);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.detect();

  if (environment.usesSqfliteFfi) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final startup = AppStartupRunner(
    logger: const AppLogger('manual_phase3_runtime_probe'),
    steps: <AppStartupStep>[
      AppStartupStep('storage', StorageUtils.init),
      AppStartupStep(
        'drafts',
        () => DraftManager().loadAllDrafts(syncRemote: false),
      ),
      AppStartupStep('network_warmup', () async {
        WkHttpClient.instance.warmUp();
      }),
      AppStartupStep('push', PushService.instance.ensureInitialized),
    ],
  );

  await startup.ensureStarted();
  runApp(const ProviderScope(child: ManualPhase3RuntimeProbeApp()));
}

class ManualPhase3RuntimeProbeApp extends StatelessWidget {
  const ManualPhase3RuntimeProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manual Phase 3 Runtime Probe',
      debugShowCheckedModeBanner: false,
      theme: WKTheme.themeData,
      home: ManualPhase3RuntimeProbeHomePage(
        autoOpenTarget:
            const String.fromEnvironment(_probeTargetEnvVar).trim().isNotEmpty
            ? const String.fromEnvironment(_probeTargetEnvVar)
            : Platform.environment[_probeTargetEnvVar],
      ),
    );
  }
}

class ManualPhase3ProbeSnapshot {
  const ManualPhase3ProbeSnapshot({
    required this.uid,
    required this.tokenPreview,
    required this.group,
    required this.members,
    required this.internalJoinGroupNo,
    required this.internalJoinAuthCode,
    required this.usedSyntheticInternalJoin,
    required this.notes,
    this.qrRawContent,
    this.internalJoinUrl,
  });

  final String uid;
  final String tokenPreview;
  final GroupInfo group;
  final List<GroupMember> members;
  final String internalJoinGroupNo;
  final String internalJoinAuthCode;
  final bool usedSyntheticInternalJoin;
  final List<String> notes;
  final String? qrRawContent;
  final String? internalJoinUrl;

  String get displayGroupName {
    final name = (group.name ?? '').trim();
    return name.isEmpty ? group.groupNo : name;
  }

  String get effectiveInternalJoinUrl {
    final explicit = internalJoinUrl?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return buildManualPhase3InternalJoinUrl(
      internalJoinGroupNo,
      internalJoinAuthCode,
    );
  }
}

class ManualPhase3RuntimeProbeHomePage extends StatefulWidget {
  const ManualPhase3RuntimeProbeHomePage({
    super.key,
    this.loadSnapshot = loadManualPhase3ProbeSnapshot,
    this.autoOpenTarget,
    this.buildGroupDetailPage = _defaultBuildGroupDetailPage,
    this.buildAllMembersPage = _defaultBuildAllMembersPage,
    this.buildAllMembersSearchPage = _defaultBuildAllMembersSearchPage,
    this.buildChatSearchEntryPage = _defaultBuildChatSearchEntryPage,
    this.buildActiveGroupScanPage = _defaultBuildActiveGroupScanPage,
    this.buildRemovedGroupScanPage = _defaultBuildRemovedGroupScanPage,
    this.buildInternalJoinScanPage = _defaultBuildInternalJoinScanPage,
    this.buildGroupScanJoinPage = _defaultBuildGroupScanJoinPage,
  });

  final ManualPhase3ProbeLoader loadSnapshot;
  final String? autoOpenTarget;
  final ManualPhase3ProbePageBuilder buildGroupDetailPage;
  final ManualPhase3ProbePageBuilder buildAllMembersPage;
  final ManualPhase3ProbePageBuilder buildAllMembersSearchPage;
  final ManualPhase3ProbePageBuilder buildChatSearchEntryPage;
  final ManualPhase3ProbePageBuilder buildActiveGroupScanPage;
  final ManualPhase3ProbePageBuilder buildRemovedGroupScanPage;
  final ManualPhase3ProbePageBuilder buildInternalJoinScanPage;
  final ManualPhase3ProbePageBuilder buildGroupScanJoinPage;

  @override
  State<ManualPhase3RuntimeProbeHomePage> createState() =>
      _ManualPhase3RuntimeProbeHomePageState();
}

class _ManualPhase3RuntimeProbeHomePageState
    extends State<ManualPhase3RuntimeProbeHomePage> {
  ManualPhase3ProbeSnapshot? _snapshot;
  Object? _error;
  bool _isLoading = true;
  bool _didAutoOpenTarget = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await widget.loadSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
      _maybeAutoOpenTarget(snapshot);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _snapshot = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Phase 3 Runtime Probe')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Failed to load probe snapshot:\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('phase3_probe_retry'),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildSummaryCard(snapshot),
        const SizedBox(height: 16),
        _buildActionCard(
          title: 'Phase 3 pages',
          children: <Widget>[
            _buildActionButton(
              key: 'phase3_probe_open_group_detail',
              label: 'Open GroupDetailPage',
              onPressed: () => _open(widget.buildGroupDetailPage(snapshot)),
            ),
            _buildActionButton(
              key: 'phase3_probe_open_all_members',
              label: 'Open AllMembersPage',
              onPressed: () => _open(widget.buildAllMembersPage(snapshot)),
            ),
            _buildActionButton(
              key: 'phase3_probe_open_all_members_search',
              label: 'Open AllMembersPage(searchMessage)',
              onPressed: () =>
                  _open(widget.buildAllMembersSearchPage(snapshot)),
            ),
            _buildActionButton(
              key: 'phase3_probe_open_chat_search_entry',
              label: 'Open ChatSearchEntryPage',
              onPressed: () => _open(widget.buildChatSearchEntryPage(snapshot)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          title: 'Scan flows',
          children: <Widget>[
            _buildActionButton(
              key: 'phase3_probe_open_active_group_scan',
              label: 'Open active-member group scan',
              onPressed: () => _open(widget.buildActiveGroupScanPage(snapshot)),
            ),
            _buildActionButton(
              key: 'phase3_probe_open_removed_group_scan',
              label: 'Open removed-member group scan',
              onPressed: () =>
                  _open(widget.buildRemovedGroupScanPage(snapshot)),
            ),
            _buildActionButton(
              key: 'phase3_probe_open_internal_join_scan',
              label: 'Open internal join scan',
              onPressed: () =>
                  _open(widget.buildInternalJoinScanPage(snapshot)),
            ),
          ],
        ),
      ],
    );
  }

  void _maybeAutoOpenTarget(ManualPhase3ProbeSnapshot snapshot) {
    if (_didAutoOpenTarget) {
      return;
    }
    final target = widget.autoOpenTarget?.trim() ?? '';
    if (target.isEmpty) {
      return;
    }
    final page = _buildPageForTarget(snapshot, target);
    if (page == null) {
      return;
    }
    _didAutoOpenTarget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _open(page);
    });
  }

  Widget? _buildPageForTarget(
    ManualPhase3ProbeSnapshot snapshot,
    String target,
  ) {
    switch (target) {
      case _probeTargetGroupDetail:
        return widget.buildGroupDetailPage(snapshot);
      case _probeTargetAllMembers:
        return widget.buildAllMembersPage(snapshot);
      case _probeTargetAllMembersSearch:
        return widget.buildAllMembersSearchPage(snapshot);
      case _probeTargetChatSearchEntry:
        return widget.buildChatSearchEntryPage(snapshot);
      case _probeTargetScanActive:
        return widget.buildActiveGroupScanPage(snapshot);
      case _probeTargetScanRemoved:
        return widget.buildRemovedGroupScanPage(snapshot);
      case _probeTargetScanInternalJoin:
        return widget.buildInternalJoinScanPage(snapshot);
      case _probeTargetGroupScanJoin:
        return widget.buildGroupScanJoinPage(snapshot);
      default:
        return null;
    }
  }

  Widget _buildSummaryCard(ManualPhase3ProbeSnapshot snapshot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Runtime snapshot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText('UID: ${snapshot.uid}'),
            SelectableText('Token: ${snapshot.tokenPreview}'),
            SelectableText('Group: ${snapshot.displayGroupName}'),
            SelectableText('GroupNo: ${snapshot.group.groupNo}'),
            SelectableText('Members: ${snapshot.members.length}'),
            SelectableText(
              'Internal join source: ${snapshot.usedSyntheticInternalJoin ? 'synthetic' : 'real'}',
            ),
            SelectableText('Internal join URL: ${snapshot.effectiveInternalJoinUrl}'),
            if ((snapshot.qrRawContent ?? '').trim().isNotEmpty)
              SelectableText('QR raw: ${snapshot.qrRawContent!.trim()}'),
            if (snapshot.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final note in snapshot.notes) Text('- $note'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        key: ValueKey<String>(key),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

Future<ManualPhase3ProbeSnapshot> loadManualPhase3ProbeSnapshot() async {
  if (!StorageUtils.isInitialized) {
    await StorageUtils.init();
  }

  final uid = StorageUtils.getUid()?.trim() ?? '';
  final token = StorageUtils.getToken()?.trim() ?? '';
  if (uid.isEmpty || token.isEmpty) {
    throw StateError(
      'No authenticated desktop session was restored from shared preferences.',
    );
  }

  ApiClient.instance.setToken(token);

  final notes = <String>[
    'Base URL: ${ApiConfig.baseUrl}',
  ];

  final groups = await GroupApi.instance.getMyGroups();
  final selectedGroupNo = groups.isNotEmpty
      ? groups.first.groupNo.trim()
      : _fallbackProbeGroupNo;
  if (groups.isEmpty) {
    notes.add(
      'getMyGroups() returned no entries, so the probe used the fallback group id.',
    );
  }

  final group = await GroupApi.instance.getGroupInfo(selectedGroupNo);
  final members = await GroupApi.instance.getGroupMembers(selectedGroupNo);

  String? qrRawContent;
  String internalJoinUrl = buildManualPhase3InternalJoinUrl(
    group.groupNo,
    _syntheticProbeAuthCode,
  );
  String internalJoinGroupNo = group.groupNo;
  String internalJoinAuthCode = _syntheticProbeAuthCode;
  var usedSyntheticInternalJoin = true;

  try {
    final qrPayload = await GroupApi.instance.getGroupQrCode(group.groupNo);
    qrRawContent = _extractProbeQrContent(qrPayload);
    final parsedResult = qrRawContent == null
        ? null
        : ScanServiceResult.rawText(qrRawContent);
    if (parsedResult != null &&
        parsedResult.isInternalJoinGroupUrl &&
        (parsedResult.joinGroupNo?.trim().isNotEmpty ?? false) &&
        (parsedResult.joinGroupAuthCode?.trim().isNotEmpty ?? false)) {
      internalJoinUrl = qrRawContent!;
      internalJoinGroupNo = parsedResult.joinGroupNo!.trim();
      internalJoinAuthCode = parsedResult.joinGroupAuthCode!.trim();
      usedSyntheticInternalJoin = false;
    } else if (qrRawContent == null || qrRawContent.trim().isEmpty) {
      notes.add(
        'Group QR payload did not contain a usable string, so the probe generated a synthetic internal join URL for route verification.',
      );
    } else {
      notes.add(
        'Real QR payload did not expose an internal join URL, so the probe generated a synthetic internal join URL for route verification.',
      );
    }
  } catch (error) {
    notes.add(
      'Failed to load group QR payload, so the probe generated a synthetic internal join URL for route verification: $error',
    );
  }

  return ManualPhase3ProbeSnapshot(
    uid: uid,
    tokenPreview: _maskProbeToken(token),
    group: group,
    members: members,
    qrRawContent: qrRawContent,
    internalJoinUrl: internalJoinUrl,
    internalJoinGroupNo: internalJoinGroupNo,
    internalJoinAuthCode: internalJoinAuthCode,
    usedSyntheticInternalJoin: usedSyntheticInternalJoin,
    notes: notes,
  );
}

String buildManualPhase3InternalJoinUrl(String groupNo, String authCode) {
  final baseUri = Uri.parse(ApiConfig.baseUrl);
  return baseUri
      .replace(
        path: '/join_group.html',
        queryParameters: <String, String>{
          'group_no': groupNo,
          'auth_code': authCode,
        },
      )
      .toString();
}

String _maskProbeToken(String token) {
  final normalized = token.trim();
  if (normalized.length <= 8) {
    return normalized;
  }
  return '${normalized.substring(0, 4)}...${normalized.substring(normalized.length - 4)}';
}

String? _extractProbeQrContent(Map<String, dynamic> payload) {
  for (final key in <String>['qrcode', 'qr_code', 'url', 'content']) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

Widget _defaultBuildGroupDetailPage(ManualPhase3ProbeSnapshot snapshot) {
  return GroupDetailPage(
    channelId: snapshot.group.groupNo,
    channelType: WKChannelType.group,
  );
}

Widget _defaultBuildAllMembersPage(ManualPhase3ProbeSnapshot snapshot) {
  return AllMembersPage(
    channelId: snapshot.group.groupNo,
    channelType: WKChannelType.group,
    channelName: snapshot.group.name,
    autoLoad: false,
    initialMembers: snapshot.members,
  );
}

Widget _defaultBuildAllMembersSearchPage(ManualPhase3ProbeSnapshot snapshot) {
  return AllMembersPage(
    channelId: snapshot.group.groupNo,
    channelType: WKChannelType.group,
    channelName: snapshot.group.name,
    searchMessage: true,
    autoLoad: false,
    initialMembers: snapshot.members,
  );
}

Widget _defaultBuildChatSearchEntryPage(ManualPhase3ProbeSnapshot snapshot) {
  return ChatSearchEntryPage(
    channelId: snapshot.group.groupNo,
    channelType: WKChannelType.group,
    channelName: snapshot.group.name,
  );
}

Widget _defaultBuildActiveGroupScanPage(ManualPhase3ProbeSnapshot snapshot) {
  return ScanResultPage(
    result: _buildProbeGroupScanResult(snapshot.group.groupNo),
    resolveGroupMember: (_) async => null,
  );
}

Widget _defaultBuildRemovedGroupScanPage(ManualPhase3ProbeSnapshot snapshot) {
  return ScanResultPage(
    result: _buildProbeGroupScanResult(snapshot.group.groupNo),
    resolveGroupMember: (_) async =>
        _buildRemovedProbeMember(snapshot.group.groupNo),
  );
}

Widget _defaultBuildInternalJoinScanPage(ManualPhase3ProbeSnapshot snapshot) {
  return ScanResultPage(result: ScanServiceResult.rawText(snapshot.effectiveInternalJoinUrl));
}

Widget _defaultBuildGroupScanJoinPage(ManualPhase3ProbeSnapshot snapshot) {
  return GroupScanJoinPage(
    groupNo: snapshot.internalJoinGroupNo,
    authCode: snapshot.internalJoinAuthCode,
  );
}

ScanServiceResult _buildProbeGroupScanResult(String groupNo) {
  return ScanServiceResult.fromJson(
    <String, dynamic>{
      'forward': 'probe',
      'type': 'group',
      'data': <String, dynamic>{'group_no': groupNo},
    },
    'probe://group/$groupNo',
  );
}

WKChannelMember _buildRemovedProbeMember(String groupNo) {
  final member = WKChannelMember();
  member.channelID = groupNo;
  member.channelType = WKChannelType.group;
  member.memberUID = '__removed_probe_member__';
  member.isDeleted = 1;
  return member;
}
