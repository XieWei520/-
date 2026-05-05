import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/chat_date_calendar_controller.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';

void main() {
  test(
    'selectCell moves the selected state from today to the tapped active day',
    () async {
      final controller = ChatDateCalendarController(
        channelId: 'group-1',
        channelType: 2,
        repository: _FakeSearchRepository(
          sections: const <SearchDateMonthSection>[
            SearchDateMonthSection(
              year: 2026,
              month: 4,
              cells: <SearchDateCell>[
                SearchDateCell(
                  year: 2026,
                  month: 4,
                  day: 3,
                  messageCount: 8,
                  anchorOrderSeq: 8000,
                  isToday: false,
                  isSelected: false,
                ),
                SearchDateCell(
                  year: 2026,
                  month: 4,
                  day: 5,
                  messageCount: 3,
                  anchorOrderSeq: 8005,
                  isToday: true,
                  isSelected: true,
                ),
              ],
            ),
          ],
        ),
      );

      await controller.load();
      controller.selectCell(
        controller.state.sections.single.cells.firstWhere(
          (cell) => !cell.isPlaceholder && cell.day == 3,
        ),
      );

      final selectedCells = controller.state.sections
          .expand((section) => section.cells)
          .where((cell) => !cell.isPlaceholder && cell.isSelected)
          .toList(growable: false);

      expect(selectedCells, hasLength(1));
      expect(selectedCells.single.dayKey, '2026-04-03');
    },
  );
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.sections = const <SearchDateMonthSection>[]});

  final List<SearchDateMonthSection> sections;

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    return sections;
  }

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchMemberHit>[];
  }

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    return const <SearchMediaItem>[];
  }

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const <SearchMessageHit>[];
  }

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const <SearchMessageHit>[];
  }
}
