import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/im_constants.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/providers/channel_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../modules/contacts/contacts_strings.dart';
import '../../modules/chat/chat_page.dart';
import '../../modules/vip/vip_guard.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_base/utils/pinyin_utils.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  final List<Friend>? initialFriends;
  final Future<GroupInfo> Function(List<String> memberIds)? onCreateGroup;
  final Future<void> Function(Friend friend)? onOpenSingleChat;

  const CreateGroupPage({
    super.key,
    this.initialFriends,
    this.onCreateGroup,
    this.onOpenSingleChat,
  });

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  static const double _contactRowHeight = 70;
  static const List<String> _sidebarLetters = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _selectedScrollController = ScrollController();
  final Set<String> _selectedUids = <String>{};

  bool _isSubmitting = false;
  bool _sidebarTouching = false;
  String _query = '';
  String? _sidebarLetter;
  String? _pendingRemovalUid;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    _selectedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = resolveContactsStrings(
      locale: Localizations.maybeLocaleOf(context),
    );
    final AsyncValue<List<Friend>> friendsState = widget.initialFriends != null
        ? AsyncValue<List<Friend>>.data(widget.initialFriends!)
        : ref.watch(friendListProvider);

    return WKSubPageScaffold(
      title: strings.selectContactsTitle,
      trailingWidth: 84,
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        child: _buildTrailingAction(strings),
      ),
      body: friendsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              strings.contactsLoadFailedMessage(error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (friends) => _buildContent(friends, strings),
      ),
    );
  }

  Widget _buildTrailingAction(ContactsStrings strings) {
    if (_selectedUids.isEmpty) {
      return const SizedBox(key: ValueKey('empty-action'));
    }

    if (_isSubmitting) {
      return const SizedBox(
        key: ValueKey('loading-action'),
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(WKColors.brand500),
        ),
      );
    }

    return WKSubPageAction(
      key: ValueKey('submit-${_selectedUids.length}'),
      text: strings.confirmWithCount(_selectedUids.length),
      onTap: _submit,
    );
  }

  Widget _buildContent(List<Friend> friends, ContactsStrings strings) {
    final allEntries = _buildEntries(friends, query: '');
    final visibleEntries = _buildEntries(friends, query: _query);
    final selectedEntries = _selectedEntries(allEntries);

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _searchFocusNode.requestFocus(),
          child: Container(
            height: 40,
            color: WKColors.homeBg,
            child: ListView(
              controller: _selectedScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 15),
              children: [
                ...selectedEntries.map(_buildSelectedChip),
                _buildSearchField(strings),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: WKColors.colorLine),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _listScrollController,
                padding: EdgeInsets.zero,
                itemCount: visibleEntries.length,
                itemBuilder: (context, index) {
                  final entry = visibleEntries[index];
                  final showSection =
                      index == 0 ||
                      visibleEntries[index - 1].section != entry.section;
                  return _buildContactRow(entry, showSection: showSection);
                },
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _CreateGroupAlphabetSidebar(
                      letters: _sidebarLetters,
                      activeLetter: _sidebarLetter,
                      onLetterTap: (letter) {
                        setState(() => _sidebarLetter = letter);
                        _jumpToSection(letter, visibleEntries);
                      },
                      onTouchingChanged: (touching) {
                        setState(() {
                          _sidebarTouching = touching;
                          if (!touching) {
                            _sidebarLetter = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
              if (_sidebarTouching && _sidebarLetter != null)
                Positioned(
                  right: 30,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _CreateGroupSidebarBubble(letter: _sidebarLetter!),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_CreateGroupEntry> _buildEntries(
    List<Friend> friends, {
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    final entries = friends
        .where((friend) => !friend.isSystemAccount)
        .where((friend) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final displayName = _displayName(friend);
          final candidates = <String>[
            friend.uid,
            displayName,
            friend.name ?? '',
            friend.remark ?? '',
            PinyinUtils.toPinyin(displayName),
          ];
          return candidates.any(
            (candidate) => candidate.toLowerCase().contains(normalizedQuery),
          );
        })
        .map((friend) {
          final displayName = _displayName(friend);
          return _CreateGroupEntry(
            friend: friend,
            displayName: displayName,
            section: _sectionFor(displayName),
          );
        })
        .toList();

    entries.sort((left, right) {
      final sectionCompare = _sectionSortValue(
        left.section,
      ).compareTo(_sectionSortValue(right.section));
      if (sectionCompare != 0) {
        return sectionCompare;
      }

      final leftPinyin = PinyinUtils.toPinyin(left.displayName).toLowerCase();
      final rightPinyin = PinyinUtils.toPinyin(right.displayName).toLowerCase();
      final nameCompare = leftPinyin.compareTo(rightPinyin);
      if (nameCompare != 0) {
        return nameCompare;
      }
      return left.friend.uid.compareTo(right.friend.uid);
    });

    return entries;
  }

  List<_CreateGroupEntry> _selectedEntries(List<_CreateGroupEntry> allEntries) {
    final entryMap = <String, _CreateGroupEntry>{
      for (final entry in allEntries) entry.friend.uid: entry,
    };
    return _selectedUids
        .map((uid) => entryMap[uid])
        .whereType<_CreateGroupEntry>()
        .toList(growable: false);
  }

  void _toggleSelection(_CreateGroupEntry entry) {
    final alreadySelected = _selectedUids.contains(entry.friend.uid);

    setState(() {
      _pendingRemovalUid = null;
      if (alreadySelected) {
        _selectedUids.remove(entry.friend.uid);
      } else {
        _selectedUids.add(entry.friend.uid);
      }
    });

    if (!alreadySelected) {
      _scrollSelectedBarToEnd();
    }
  }

  void _scrollSelectedBarToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_selectedScrollController.hasClients) {
        return;
      }
      _selectedScrollController.animateTo(
        _selectedScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleSelectedChipTap(_CreateGroupEntry entry) {
    setState(() {
      if (_pendingRemovalUid == entry.friend.uid) {
        _selectedUids.remove(entry.friend.uid);
        _pendingRemovalUid = null;
      } else {
        _pendingRemovalUid = entry.friend.uid;
      }
    });
  }

  void _handleBackspaceDelete() {
    if (_selectedUids.isEmpty) {
      return;
    }

    setState(() {
      _selectedUids.remove(_selectedUids.last);
      _pendingRemovalUid = null;
    });
  }

  Widget _buildSelectedChip(_CreateGroupEntry entry) {
    final isPendingRemoval = _pendingRemovalUid == entry.friend.uid;
    final chipColor = isPendingRemoval
        ? WKColors.danger
        : WKColors.getNameColorFromString(entry.displayName);

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GestureDetector(
        onTap: () => _handleSelectedChipTap(entry),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.linear,
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(1, 3, 5, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.linear,
                switchOutCurve: Curves.linear,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: RotationTransition(
                      turns: Tween<double>(
                        begin: 0,
                        end: 0.25,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: isPendingRemoval
                    ? const SizedBox(
                        key: ValueKey('remove-icon'),
                        width: 25,
                        height: 25,
                        child: Icon(
                          Icons.close,
                          color: WKColors.white,
                          size: 16,
                        ),
                      )
                    : WKAvatar(
                        key: const ValueKey('member-avatar'),
                        url: entry.friend.avatar,
                        name: entry.displayName,
                        size: 25,
                      ),
              ),
              const SizedBox(width: 5),
              Text(
                entry.displayName,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 13,
                  color: WKColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ContactsStrings strings) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final searchFieldWidth = switch (viewportWidth) {
      >= 1200 => 260.0,
      >= 700 => 220.0,
      _ => 100.0,
    };

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 5),
      child: Center(
        child: SizedBox(
          width: searchFieldWidth,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  _searchController.text.isEmpty) {
                _handleBackspaceDelete();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: strings.searchPlaceholder,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: WKColors.color999,
                ),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                  _pendingRemovalUid = null;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(
    _CreateGroupEntry entry, {
    required bool showSection,
  }) {
    final isSelected = _selectedUids.contains(entry.friend.uid);

    return Material(
      color: WKColors.surface,
      child: InkWell(
        onTap: _isSubmitting ? null : () => _toggleSelection(entry),
        child: SizedBox(
          height: _contactRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: showSection
                      ? Text(
                          entry.section,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: WKColors.colorDark,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: WKAvatar(
                          url: entry.friend.avatar,
                          name: entry.displayName,
                          size: 40,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WKColors.brand500
                                : WKColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: WKColors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: WKColors.white,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(Friend friend) {
    final remark = (friend.remark ?? '').trim();
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = (friend.name ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return friend.uid;
  }

  String _sectionFor(String name) {
    if (name.isEmpty) {
      return '#';
    }
    final letter = PinyinUtils.getFirstLetter(name).toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(letter) ? letter : '#';
  }

  int _sectionSortValue(String section) {
    if (section == '#') {
      return 999;
    }
    return section.codeUnitAt(0);
  }

  void _jumpToSection(String section, List<_CreateGroupEntry> entries) {
    if (!_listScrollController.hasClients) {
      return;
    }

    final index = entries.indexWhere((entry) => entry.section == section);
    if (index < 0) {
      return;
    }

    _listScrollController.animateTo(
      index * _contactRowHeight,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  List<Friend> _currentFriends() {
    if (widget.initialFriends != null) {
      return widget.initialFriends!;
    }

    return ref
        .read(friendListProvider)
        .maybeWhen(data: (friends) => friends, orElse: () => const <Friend>[]);
  }

  Future<void> _submit() async {
    if (_selectedUids.isEmpty || _isSubmitting) {
      return;
    }

    final selectedEntries = _selectedEntries(
      _buildEntries(_currentFriends(), query: ''),
    );
    if (selectedEntries.isEmpty) {
      return;
    }

    if (selectedEntries.length == 1) {
      final friend = selectedEntries.single.friend;
      if (widget.onOpenSingleChat != null) {
        await widget.onOpenSingleChat!(friend);
        return;
      }
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            channelId: friend.uid,
            channelType: ChannelType.personal,
            channelName: _displayName(friend),
          ),
        ),
      );
      return;
    }
    if (!await guardVipFeature(
      context,
      entitlement: VipEntitlement.createGroup,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final selectedIds = selectedEntries
          .map((entry) => entry.friend.uid)
          .toList(growable: false);
      final selectedNames = selectedEntries
          .map((entry) => entry.displayName)
          .toList(growable: false);
      final group = widget.onCreateGroup != null
          ? await widget.onCreateGroup!(selectedIds)
          : await GroupApi.instance.createGroup(
              selectedIds,
              memberNames: selectedNames,
            );
      await ref.read(myGroupListProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<GroupInfo>(group);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final strings = resolveContactsStrings(
        locale: Localizations.maybeLocaleOf(context),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.createGroupFailed(error))));
      setState(() => _isSubmitting = false);
    }
  }
}

class _CreateGroupAlphabetSidebar extends StatelessWidget {
  final List<String> letters;
  final String? activeLetter;
  final ValueChanged<String> onLetterTap;
  final ValueChanged<bool> onTouchingChanged;

  const _CreateGroupAlphabetSidebar({
    required this.letters,
    required this.activeLetter,
    required this.onLetterTap,
    required this.onTouchingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void pickLetter(Offset localPosition) {
          if (letters.isEmpty || constraints.maxHeight <= 0) {
            return;
          }
          final itemExtent = constraints.maxHeight / letters.length;
          final rawIndex = (localPosition.dy / itemExtent).floor();
          final index = rawIndex.clamp(0, letters.length - 1);
          onLetterTap(letters[index]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            onTouchingChanged(true);
            pickLetter(details.localPosition);
          },
          onVerticalDragDown: (details) {
            onTouchingChanged(true);
            pickLetter(details.localPosition);
          },
          onVerticalDragUpdate: (details) {
            onTouchingChanged(true);
            pickLetter(details.localPosition);
          },
          onVerticalDragEnd: (_) => onTouchingChanged(false),
          onVerticalDragCancel: () => onTouchingChanged(false),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final letter in letters)
                SizedBox(
                  width: 20,
                  height: 15,
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: activeLetter == letter ? 16 : 10,
                        fontWeight: activeLetter == letter
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: WKColors.brand500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateGroupSidebarBubble extends StatelessWidget {
  final String letter;

  const _CreateGroupSidebarBubble({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: WKColors.brand500,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontFamily: WKFontFamily.title,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: WKColors.white,
        ),
      ),
    );
  }
}

class _CreateGroupEntry {
  final Friend friend;
  final String displayName;
  final String section;

  const _CreateGroupEntry({
    required this.friend,
    required this.displayName,
    required this.section,
  });
}
