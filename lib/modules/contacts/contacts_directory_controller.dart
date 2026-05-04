import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/wukong_base/utils/pinyin_utils.dart';

@immutable
class ContactsDirectoryEntry {
  const ContactsDirectoryEntry({
    required this.friend,
    required this.sortKey,
    required this.sectionLetter,
  });

  final Friend friend;
  final String sortKey;
  final String sectionLetter;
}

@immutable
class ContactsDirectorySection {
  const ContactsDirectorySection({required this.letter, required this.entries});

  final String letter;
  final List<ContactsDirectoryEntry> entries;
}

@immutable
class ContactsDirectoryData {
  const ContactsDirectoryData({required this.sections, required this.letters});

  final List<ContactsDirectorySection> sections;
  final List<String> letters;
}

class ContactsDirectoryController {
  ContactsDirectoryData buildDirectory(List<Friend> friends) {
    final entries = friends.map((friend) {
      final sortKey = _resolveName(friend).trim();
      final letter = _resolveSortLetter(sortKey);
      return ContactsDirectoryEntry(
        friend: friend,
        sortKey: sortKey,
        sectionLetter: letter,
      );
    }).toList();

    entries.sort((left, right) {
      final sectionCompare = _sectionSortValue(
        left.sectionLetter,
      ).compareTo(_sectionSortValue(right.sectionLetter));
      if (sectionCompare != 0) {
        return sectionCompare;
      }

      final leftPinyin = PinyinUtils.toPinyin(left.sortKey).toLowerCase();
      final rightPinyin = PinyinUtils.toPinyin(right.sortKey).toLowerCase();
      final nameCompare = leftPinyin.compareTo(rightPinyin);
      if (nameCompare != 0) {
        return nameCompare;
      }
      return left.friend.uid.compareTo(right.friend.uid);
    });

    final letters = <String>[];
    final sections = <ContactsDirectorySection>[];
    for (final entry in entries) {
      if (!letters.contains(entry.sectionLetter)) {
        letters.add(entry.sectionLetter);
      }
    }
    for (final letter in letters) {
      sections.add(
        ContactsDirectorySection(
          letter: letter,
          entries: entries
              .where((entry) => entry.sectionLetter == letter)
              .toList(),
        ),
      );
    }
    return ContactsDirectoryData(sections: sections, letters: letters);
  }

  String _resolveName(Friend friend) {
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

  String _resolveSortLetter(String name) {
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
}
