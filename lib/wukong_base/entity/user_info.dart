/// User info entity
class WKUserInfo {
  String uid;
  String name;
  String avatar;
  int sex;
  String? phone;

  WKUserInfo({
    this.uid = '',
    this.name = '',
    this.avatar = '',
    this.sex = 1,
    this.phone,
  });

  factory WKUserInfo.fromJson(Map<String, dynamic> json) {
    return WKUserInfo(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      sex: json['sex'] ?? 1,
      phone: json['phone'],
    );
  }
}
