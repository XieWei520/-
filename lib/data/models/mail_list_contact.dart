class MailListContact {
  final String name;
  final String phone;
  final String? uid;
  final String? vercode;
  final String? avatarUrl;
  final bool isFriend;

  const MailListContact({
    required this.name,
    required this.phone,
    this.uid,
    this.vercode,
    this.avatarUrl,
    this.isFriend = false,
  });

  String get displayName {
    final value = name.trim();
    return value.isEmpty ? phone.trim() : value;
  }

  String get normalizedUid {
    final value = uid?.trim() ?? '';
    return value.isEmpty ? '' : value;
  }

  bool get isRegistered => normalizedUid.isNotEmpty;
}

class MailListUploadContact {
  final String name;
  final String zone;
  final String phone;

  const MailListUploadContact({
    required this.name,
    required this.zone,
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'zone': zone, 'phone': phone};
  }
}

class MailListMatchedContact {
  final String name;
  final String zone;
  final String phone;
  final String uid;
  final String vercode;
  final bool isFriend;

  const MailListMatchedContact({
    required this.name,
    required this.zone,
    required this.phone,
    required this.uid,
    required this.vercode,
    required this.isFriend,
  });

  factory MailListMatchedContact.fromJson(Map<String, dynamic> json) {
    return MailListMatchedContact(
      name: json['name']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      vercode: json['vercode']?.toString() ?? '',
      isFriend: _parseBoolLike(json['is_friend']),
    );
  }
}

bool _parseBoolLike(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value.toInt() == 1;
  }
  final normalized = value?.toString().trim() ?? '';
  return normalized == '1' || normalized.toLowerCase() == 'true';
}
