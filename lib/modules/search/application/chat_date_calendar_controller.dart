import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'chat_keyword_search_controller.dart';
import 'search_providers.dart';

@immutable
class ChatDateCalendarState {
  const ChatDateCalendarState({
    this.sections = const <SearchDateMonthSection>[],
    this.isLoading = false,
    this.error,
  });

  final List<SearchDateMonthSection> sections;
  final bool isLoading;
  final String? error;

  ChatDateCalendarState copyWith({
    List<SearchDateMonthSection>? sections,
    bool? isLoading,
    Object? error = _errorSentinel,
  }) {
    return ChatDateCalendarState(
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const Object _errorSentinel = Object();

final chatDateCalendarControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatDateCalendarController, ChatDateCalendarState, ChatSearchTarget>(
      (ref, target) {
        final controller = ChatDateCalendarController(
          channelId: target.channelId,
          channelType: target.channelType,
          repository: ref.read(searchRepositoryProvider),
        );
        controller.load();
        return controller;
      },
    );

class ChatDateCalendarController extends StateNotifier<ChatDateCalendarState> {
  ChatDateCalendarController({
    required this.channelId,
    required this.channelType,
    required SearchRepository repository,
  }) : _repository = repository,
       super(const ChatDateCalendarState());

  final String channelId;
  final int channelType;
  final SearchRepository _repository;

  Future<void> load() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final sections = await _repository.loadDateCalendar(
        channelId: channelId,
        channelType: channelType,
      );
      if (!mounted) {
        return;
      }
      state = ChatDateCalendarState(
        sections: _sortSections(sections),
        isLoading: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      state = ChatDateCalendarState(
        sections: const <SearchDateMonthSection>[],
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void selectCell(SearchDateCell cell) {
    if (cell.isPlaceholder || !cell.canOpen) {
      return;
    }

    final selectedKey = cell.dayKey;
    final updatedSections = state.sections.map((section) {
      final updatedCells = section.cells.map((existing) {
        if (existing.isPlaceholder) {
          return existing;
        }
        final shouldSelect = existing.dayKey == selectedKey;
        if (existing.isSelected == shouldSelect) {
          return existing;
        }
        return existing.copyWith(isSelected: shouldSelect);
      }).toList(growable: false);

      return SearchDateMonthSection(
        year: section.year,
        month: section.month,
        cells: List<SearchDateCell>.unmodifiable(updatedCells),
      );
    }).toList(growable: false);

    state = state.copyWith(
      sections: List<SearchDateMonthSection>.unmodifiable(updatedSections),
    );
  }

  List<SearchDateMonthSection> _sortSections(
    List<SearchDateMonthSection> sections,
  ) {
    final sorted = List<SearchDateMonthSection>.from(sections);
    sorted.sort((left, right) {
      final yearCompare = left.year.compareTo(right.year);
      if (yearCompare != 0) {
        return yearCompare;
      }
      return left.month.compareTo(right.month);
    });
    return List<SearchDateMonthSection>.unmodifiable(sorted);
  }
}
