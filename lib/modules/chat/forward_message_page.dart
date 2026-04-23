import 'package:flutter/material.dart';

import 'chat_scene_gateway.dart';
import 'message_forwarding.dart';

const String _title = '选择会话';
const String _searchHint = '搜索(精确搜索)';
const String _emptyChats = '暂无会话';
const String _loadFailure = '加载会话失败';
const String _confirmLabel = '确定';
const String _submittingLabel = '发送中...';

class ForwardMessagePage extends StatefulWidget {
  const ForwardMessagePage({
    super.key,
    required this.payloads,
    required this.channelId,
    required this.channelType,
    this.gateway,
  });

  final List<ForwardPayload> payloads;
  final String channelId;
  final int channelType;
  final ChatSceneGateway? gateway;

  @override
  State<ForwardMessagePage> createState() => _ForwardMessagePageState();
}

class _ForwardMessagePageState extends State<ForwardMessagePage> {
  late final ChatSceneGateway _gateway =
      widget.gateway ?? ApiChatSceneGateway();
  late final Future<List<ForwardTarget>> _targetsFuture = _gateway
      .loadForwardTargets(
        excludedChannelId: widget.channelId,
        excludedChannelType: widget.channelType,
      );

  final Set<String> _selectedTargetKeys = <String>{};
  String _query = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForwardTarget>>(
      future: _targetsFuture,
      builder: (context, snapshot) {
        final allTargets = snapshot.data ?? const <ForwardTarget>[];
        final filteredTargets = filterForwardTargets(allTargets, _query);
        final submitText = _isSubmitting
            ? _submittingLabel
            : _selectedTargetKeys.isEmpty
                ? _confirmLabel
                : '$_confirmLabel(${_selectedTargetKeys.length})';

        return Scaffold(
          appBar: AppBar(title: const Text(_title)),
          body: switch (snapshot.connectionState) {
            ConnectionState.none ||
            ConnectionState.waiting ||
            ConnectionState.active => const Center(
              child: CircularProgressIndicator(),
            ),
            ConnectionState.done => snapshot.hasError
                ? const Center(child: Text(_loadFailure))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: TextField(
                          key: const ValueKey<String>('forward-search-field'),
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: _searchHint,
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredTargets.isEmpty
                            ? const Center(child: Text(_emptyChats))
                            : ListView.builder(
                                itemCount: filteredTargets.length,
                                itemBuilder: (context, index) {
                                  final target = filteredTargets[index];
                                  final selected = _selectedTargetKeys.contains(
                                    target.key,
                                  );
                                  return ListTile(
                                    key: ValueKey<String>(
                                      'forward-target-${target.key}',
                                    ),
                                    leading: CircleAvatar(
                                      child: Text(
                                        targetAvatarLabel(target.displayName),
                                      ),
                                    ),
                                    title: Text(target.displayName),
                                    subtitle: target.subtitle.trim().isEmpty
                                        ? null
                                        : Text(target.subtitle),
                                    trailing: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (!selected) {
                                          _selectedTargetKeys.add(target.key);
                                        } else {
                                          _selectedTargetKeys.remove(target.key);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          },
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey<String>('forward-submit'),
                  onPressed: _selectedTargetKeys.isEmpty || _isSubmitting
                      ? null
                      : () => _submit(allTargets),
                  child: Text(submitText),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(List<ForwardTarget> allTargets) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final selectedTargets = allTargets
          .where((target) => _selectedTargetKeys.contains(target.key))
          .toList(growable: false);
      await _gateway.sendForwardPayloads(widget.payloads, selectedTargets);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
