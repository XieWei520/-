import 'package:flutter/material.dart';

import '../../data/models/group_notice_history.dart';
import '../../service/api/group_api.dart';

class GroupNoticeHistoryPage extends StatefulWidget {
  final String groupId;

  const GroupNoticeHistoryPage({super.key, required this.groupId});

  @override
  State<GroupNoticeHistoryPage> createState() => _GroupNoticeHistoryPageState();
}

class _GroupNoticeHistoryPageState extends State<GroupNoticeHistoryPage> {
  List<GroupNoticeHistory> _items = const <GroupNoticeHistory>[];
  bool _isLoading = true;
  String? _error;

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
      final items = await GroupApi.instance.getGroupNoticeHistory(
        widget.groupId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告修改记录')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            '暂无公告修改记录',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '后续每次修改群公告都会保留在这里',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        final operator = item.operatorName.trim().isNotEmpty
            ? item.operatorName.trim()
            : (item.operatorUid.trim().isNotEmpty
                  ? item.operatorUid.trim()
                  : '未知成员');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      operator,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    item.createdAt,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.notice.trim().isEmpty ? '公告被清空' : item.notice,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
