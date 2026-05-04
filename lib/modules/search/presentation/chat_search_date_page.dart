import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_page.dart';
import '../application/chat_date_calendar_controller.dart';
import '../application/chat_keyword_search_controller.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'widgets/search_date_calendar.dart';

class ChatSearchDatePage extends ConsumerStatefulWidget {
  const ChatSearchDatePage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  ConsumerState<ChatSearchDatePage> createState() => _ChatSearchDatePageState();
}

class _ChatSearchDatePageState extends ConsumerState<ChatSearchDatePage> {
  final ScrollController _scrollController = ScrollController();
  String? _autoScrolledSectionKey;

  ChatSearchTarget get _target => ChatSearchTarget(
    channelId: widget.channelId,
    channelType: widget.channelType,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatDateCalendarControllerProvider(_target));
    final controller = ref.read(
      chatDateCalendarControllerProvider(_target).notifier,
    );
    final strings = DateSearchStrings.of(context);

    _scheduleAutoScroll(state.sections);

    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: SafeArea(
        child: switch ((
          state.isLoading,
          state.error != null,
          state.sections.isEmpty,
        )) {
          (true, _, true) => const Center(child: CircularProgressIndicator()),
          (_, true, true) => Center(
            child: Column(
              key: const ValueKey<String>('search-date-error-state'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error!),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey<String>('search-date-retry'),
                  onPressed: controller.load,
                  child: Text(strings.retry),
                ),
              ],
            ),
          ),
          _ => SearchDateCalendar(
            sections: state.sections,
            scrollController: _scrollController,
            onTapCell: _openDayCell,
          ),
        },
      ),
    );
  }

  void _scheduleAutoScroll(List<SearchDateMonthSection> sections) {
    if (sections.isEmpty) {
      return;
    }

    final latestSectionKey = sections.last.sectionKey;
    if (_autoScrolledSectionKey == latestSectionKey) {
      return;
    }
    _autoScrolledSectionKey = latestSectionKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToLatestMonth();
    });
  }

  void _jumpToLatestMonth([int remainingPasses = 2]) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final previousMaxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(previousMaxExtent);

    if (remainingPasses <= 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final nextMaxExtent = _scrollController.position.maxScrollExtent;
      if ((nextMaxExtent - previousMaxExtent).abs() < 1) {
        return;
      }
      _jumpToLatestMonth(remainingPasses - 1);
    });
  }

  Future<void> _openDayCell(SearchDateCell cell) async {
    if (!cell.canOpen) {
      return;
    }

    ref
        .read(chatDateCalendarControllerProvider(_target).notifier)
        .selectCell(cell);

    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromDateCell(
      cell: cell,
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      source: 'search-date',
    );
    final coordinator = ref.read(chatLocateCoordinatorProvider);
    final request = await coordinator.buildOpenRequestFromIntent(intent);
    if (!mounted) {
      return;
    }

    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            channelId: request.channelId,
            channelType: request.channelType,
            channelName: request.channelName ?? widget.channelName,
            initialAroundOrderSeq: request.orderSeq,
          ),
        ),
      ),
    );

    final feedbackMessage = request.feedbackMessage;
    if (feedbackMessage == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(feedbackMessage)));
  }
}
