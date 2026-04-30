import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../core/utils/platform_utils.dart';
import '../../data/models/mail_list_contact.dart';
import '../api/user_api.dart';

abstract class MailListLoader {
  Future<List<MailListContact>> loadContacts();
}

abstract class MailListApi {
  Future<void> uploadMailListContacts(List<MailListUploadContact> contacts);

  Future<List<MailListMatchedContact>> getMailListContacts();
}

abstract class MailListContactSource {
  Future<List<MailListDeviceContact>> readContacts();
}

class MailListDeviceContact {
  final String name;
  final String phone;

  const MailListDeviceContact({required this.name, required this.phone});
}

class MailListService implements MailListLoader {
  MailListService({MailListContactSource? contactSource, MailListApi? api})
    : contactSource = contactSource ?? const FlutterMailListContactSource(),
      api = api ?? _UserApiMailListApi();

  static final MailListService instance = MailListService();

  final MailListContactSource contactSource;
  final MailListApi api;

  @override
  Future<List<MailListContact>> loadContacts() async {
    final localContacts = await contactSource.readContacts();
    final uploadedContacts = normalizeContacts(localContacts);
    if (uploadedContacts.isEmpty) {
      return const <MailListContact>[];
    }

    await api.uploadMailListContacts(uploadedContacts);
    final matchedContacts = await api.getMailListContacts();
    return mergeContacts(
      uploadedContacts: uploadedContacts,
      matchedContacts: matchedContacts,
    );
  }

  @visibleForTesting
  static List<MailListUploadContact> normalizeContacts(
    List<MailListDeviceContact> contacts,
  ) {
    final normalized = <MailListUploadContact>[];
    final seenPhones = <String>{};

    for (final contact in contacts) {
      final phone = _normalizePhone(contact.phone);
      if (phone.isEmpty || !seenPhones.add(phone)) {
        continue;
      }

      normalized.add(
        MailListUploadContact(
          name: _normalizeName(contact.name),
          zone: '',
          phone: phone,
        ),
      );
    }

    return normalized;
  }

  @visibleForTesting
  static List<MailListContact> mergeContacts({
    required List<MailListUploadContact> uploadedContacts,
    required List<MailListMatchedContact> matchedContacts,
  }) {
    final merged = <MailListContact>[];
    final matchedPhones = <String>{};

    for (final contact in matchedContacts) {
      final phone = _normalizePhone(contact.phone);
      matchedPhones.add(phone);
      merged.add(
        MailListContact(
          name: contact.name,
          phone: phone,
          uid: contact.uid,
          vercode: contact.vercode,
          isFriend: contact.isFriend,
        ),
      );
    }

    for (final contact in uploadedContacts) {
      if (matchedPhones.contains(contact.phone)) {
        continue;
      }
      merged.add(MailListContact(name: contact.name, phone: contact.phone));
    }

    return merged;
  }

  static String _normalizeName(String rawName) {
    return rawName.trim().replaceAll(' ', '');
  }

  static String _normalizePhone(String rawPhone) {
    return rawPhone.trim().replaceAll(' ', '').replaceAll('+', '00');
  }
}

class FlutterMailListContactSource implements MailListContactSource {
  const FlutterMailListContactSource();

  @override
  Future<List<MailListDeviceContact>> readContacts() async {
    if (!PlatformUtils.isAndroid && !PlatformUtils.isIOS) {
      return const <MailListDeviceContact>[];
    }

    final permission = await fc.FlutterContacts.permissions.request(
      fc.PermissionType.read,
    );
    if (permission != fc.PermissionStatus.granted &&
        permission != fc.PermissionStatus.limited) {
      throw Exception('通讯录权限被拒绝');
    }

    final contacts = await fc.FlutterContacts.getAll(
      properties: <fc.ContactProperty>{
        fc.ContactProperty.name,
        fc.ContactProperty.phone,
      },
    );

    return contacts
        .map((contact) {
          final phone = contact.phones.isEmpty
              ? ''
              : contact.phones.first.number;
          return MailListDeviceContact(
            name: contact.displayName ?? '',
            phone: phone,
          );
        })
        .toList(growable: false);
  }
}

class _UserApiMailListApi implements MailListApi {
  @override
  Future<List<MailListMatchedContact>> getMailListContacts() {
    return UserApi.instance.getMailListContacts();
  }

  @override
  Future<void> uploadMailListContacts(List<MailListUploadContact> contacts) {
    return UserApi.instance.uploadMailListContacts(contacts);
  }
}
