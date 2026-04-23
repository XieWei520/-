import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/auth_api.dart';

void main() {
  test('LoginResp treats legacy status 110 payload as login verification', () {
    final resp = LoginResp.fromJson(<String, dynamic>{
      'status': 110,
      'msg': '需要验证手机号码！',
      'uid': 'u_verify',
      'phone': '138******00',
    }, statusCode: 400);

    expect(resp.code, 110);
    expect(resp.requiresLoginVerification, isTrue);
    expect(resp.data?.uid, 'u_verify');
    expect(resp.data?.phone, '138******00');
  });
}
