import 'package:flutter/material.dart';

import '../../domain/search_models.dart';

@immutable
class DateSearchStrings {
  const DateSearchStrings({
    required this.title,
    required this.today,
    required this.noData,
    required this.retry,
    required this.weekdays,
  });

  final String title;
  final String today;
  final String noData;
  final String retry;
  final List<String> weekdays;

  static DateSearchStrings of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isChinese = languageCode.toLowerCase().startsWith('zh');
    return DateSearchStrings(
      title: isChinese ? '查找聊天记录' : 'Search Chat History',
      today: isChinese ? '今天' : 'Today',
      noData: isChinese ? '暂无数据' : 'No data',
      retry: isChinese ? '重试' : 'Retry',
      weekdays: List<String>.from(
        MaterialLocalizations.of(context).narrowWeekdays,
        growable: false,
      ),
    );
  }
}

class SearchDateCalendar extends StatelessWidget {
  const SearchDateCalendar({
    super.key,
    required this.sections,
    required this.onTapCell,
    this.scrollController,
  });

  final List<SearchDateMonthSection> sections;
  final ValueChanged<SearchDateCell> onTapCell;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final strings = DateSearchStrings.of(context);
    final palette = _DateSearchPalette.resolve(Theme.of(context).brightness);

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.pageBackground),
      child: Column(
        children: [
          Container(
            color: palette.weekdayBackground,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: List<Widget>.generate(strings.weekdays.length, (index) {
                return Expanded(
                  child: Center(
                    child: Text(
                      strings.weekdays[index],
                      key: ValueKey<String>('search-date-weekday-$index'),
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: sections.isEmpty
                ? Center(
                    key: const ValueKey<String>('search-date-empty-state'),
                    child: Text(
                      strings.noData,
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _MonthSection(
                        section: section,
                        strings: strings,
                        palette: palette,
                        onTapCell: onTapCell,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.section,
    required this.strings,
    required this.palette,
    required this.onTapCell,
  });

  final SearchDateMonthSection section;
  final DateSearchStrings strings;
  final _DateSearchPalette palette;
  final ValueChanged<SearchDateCell> onTapCell;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            section.sectionKey,
            key: ValueKey<String>('search-date-section-${section.sectionKey}'),
            style: TextStyle(color: palette.secondaryText, fontSize: 14),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: section.cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final cell = section.cells[index];
            return _DateCell(
              cell: cell,
              sectionKey: section.sectionKey,
              strings: strings,
              palette: palette,
              onTap: () => onTapCell(cell),
            );
          },
        ),
      ],
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.cell,
    required this.sectionKey,
    required this.strings,
    required this.palette,
    required this.onTap,
  });

  final SearchDateCell cell;
  final String sectionKey;
  final DateSearchStrings strings;
  final _DateSearchPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (cell.isPlaceholder) {
      return SizedBox.expand(
        key: ValueKey<String>(
          'search-date-placeholder-$sectionKey-${cell.weekdayOffset}',
        ),
      );
    }

    final dayKey =
        '${cell.year}-${cell.month.toString().padLeft(2, '0')}-${cell.day.toString().padLeft(2, '0')}';
    final dayLabel = cell.day.toString().padLeft(2, '0');
    final isSelected = cell.isSelected;
    final canOpen = cell.canOpen;

    return Center(
      child: InkWell(
        key: ValueKey<String>('search-date-cell-$dayKey'),
        onTap: canOpen ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                key: ValueKey<String>('search-date-day-chip-$dayKey'),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? palette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  dayLabel,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : canOpen
                        ? palette.primaryText
                        : palette.secondaryText,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                key: ValueKey<String>('search-date-today-$dayKey'),
                cell.isToday ? strings.today : ' ',
                style: TextStyle(
                  color: cell.isToday ? palette.accent : Colors.transparent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _DateSearchPalette {
  const _DateSearchPalette({
    required this.pageBackground,
    required this.weekdayBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
  });

  final Color pageBackground;
  final Color weekdayBackground;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;

  static _DateSearchPalette resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _DateSearchPalette(
        pageBackground: Color(0xFF111315),
        weekdayBackground: Color(0xFF050505),
        primaryText: Color(0xFFFFFFFF),
        secondaryText: Color(0xFF999999),
        accent: Color(0xFFF65835),
      );
    }
    return const _DateSearchPalette(
      pageBackground: Color(0xFFF6F6F6),
      weekdayBackground: Color(0xFFE7E7E7),
      primaryText: Color(0xFF313131),
      secondaryText: Color(0xFF999999),
      accent: Color(0xFFF65835),
    );
  }
}
