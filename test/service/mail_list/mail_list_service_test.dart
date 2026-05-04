import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/mail_list_contact.dart';
import 'package:wukong_im_app/service/mail_list/mail_list_service.dart';

void main() {
  group('MailListService', () {
    test(
      'loadContacts normalizes uploads and merges matched contacts first',
      () async {
        final contactSource =
            _FakeMailListContactSource(const <MailListDeviceContact>[
              MailListDeviceContact(name: ' Alice ', phone: '138 0013 8000'),
              MailListDeviceContact(
                name: 'Alice Duplicate',
                phone: '13800138000',
              ),
              MailListDeviceContact(name: 'Berta', phone: '+8613900139000'),
              MailListDeviceContact(name: '  ', phone: '   '),
            ]);
        final api = _FakeMailListApi(
          matchedContacts: const <MailListMatchedContact>[
            MailListMatchedContact(
              name: 'Berta',
              zone: '',
              phone: '008613900139000',
              uid: 'u_berta',
              vercode: 'vc_berta',
              isFriend: false,
            ),
          ],
        );
        final service = MailListService(contactSource: contactSource, api: api);

        final contacts = await service.loadContacts();

        expect(
          api.uploadedContacts
              .map(
                (contact) => <String, String>{
                  'name': contact.name,
                  'zone': contact.zone,
                  'phone': contact.phone,
                },
              )
              .toList(),
          const <Map<String, String>>[
            <String, String>{
              'name': 'Alice',
              'zone': '',
              'phone': '13800138000',
            },
            <String, String>{
              'name': 'Berta',
              'zone': '',
              'phone': '008613900139000',
            },
          ],
        );
        expect(contacts, hasLength(2));
        expect(contacts.first.uid, 'u_berta');
        expect(contacts.first.isRegistered, isTrue);
        expect(contacts.last.phone, '13800138000');
        expect(contacts.last.isRegistered, isFalse);
      },
    );
  });
}

class _FakeMailListApi implements MailListApi {
  _FakeMailListApi({required this.matchedContacts});

  final List<MailListMatchedContact> matchedContacts;
  List<MailListUploadContact> uploadedContacts =
      const <MailListUploadContact>[];

  @override
  Future<List<MailListMatchedContact>> getMailListContacts() async {
    return matchedContacts;
  }

  @override
  Future<void> uploadMailListContacts(
    List<MailListUploadContact> contacts,
  ) async {
    uploadedContacts = List<MailListUploadContact>.from(contacts);
  }
}

class _FakeMailListContactSource implements MailListContactSource {
  const _FakeMailListContactSource(this.contacts);

  final List<MailListDeviceContact> contacts;

  @override
  Future<List<MailListDeviceContact>> readContacts() async {
    return contacts;
  }
}
