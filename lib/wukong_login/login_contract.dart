import '../wukong_base/base/base_contract.dart';

/// Login View interface
abstract class LoginView extends BaseView {
  void loginSuccess(UserInfo userInfo);
  void loginFail(int code, String uid, String phone);
  void setCountryCode(List<CountryCode> list);
  void sendCodeResult(int code, String msg);
  void resetPwdResult(int code, String msg);
  void registerResult(int code, String msg, bool exist);
  dynamic getVerificationCodeBtn();
  dynamic getNameEt();
}

/// Login Presenter interface
abstract class LoginPresenterContract extends BasePresenter<LoginView> {
  void login(String username, String password);
  void sendCode(String phone, String zone, int type);
  void register(String username, String password, String code, String zone);
  void resetPassword(String phone, String newPassword, String code, String zone);
  void getCountryCodes();
}

/// User info model
class UserInfo {
  String token;
  String uid;
  String username;
  String name;
  String phone;
  String avatar;
  int sex;
  String zone;
  String? imToken;

  UserInfo({
    this.token = '',
    this.uid = '',
    this.username = '',
    this.name = '',
    this.phone = '',
    this.avatar = '',
    this.sex = 1,
    this.zone = '0086',
    this.imToken,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      token: json['token'] ?? '',
      uid: json['uid'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      avatar: json['avatar'] ?? '',
      sex: json['sex'] ?? 1,
      zone: json['zone'] ?? '0086',
      imToken: json['im_token'] ?? json['imToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'uid': uid,
      'username': username,
      'name': name,
      'phone': phone,
      'avatar': avatar,
      'sex': sex,
      'zone': zone,
      'im_token': imToken,
    };
  }

  bool get needCompleteInfo => name.isEmpty;
}

/// Country code model
class CountryCode {
  final String code;
  final String name;
  final String nameEn;

  CountryCode({
    required this.code,
    required this.name,
    required this.nameEn,
  });

  factory CountryCode.fromJson(Map<String, dynamic> json) {
    return CountryCode(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      nameEn: json['name_en'] ?? json['nameEn'] ?? '',
    );
  }

  String get displayName => '$name (+${code.substring(2)})';
}

/// Login params
class LoginParams {
  final String username;
  final String password;
  final String? zone;

  LoginParams({
    required this.username,
    required this.password,
    this.zone,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      if (zone != null) 'zone': zone,
    };
  }
}

/// Register params
class RegisterParams {
  final String username;
  final String password;
  final String code;
  final String? zone;

  RegisterParams({
    required this.username,
    required this.password,
    required this.code,
    this.zone,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'code': code,
      if (zone != null) 'zone': zone,
    };
  }
}

/// SMS type enum
class SMSType {
  static const int register = 1;
  static const int forgetPassword = 2;
}
