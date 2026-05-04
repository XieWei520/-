import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';

void main() {
  test('app name is frozen to approved brand', () {
    expect(AppConfig.appName, '\u4fe1\u606f\u5e73\u6743');
  });

  test('auth titles and subtitles follow approved brand copy', () {
    expect(AuthCopy.loginTitle(AppConfig.appName), '\u6b22\u8fce\u767b\u5f55');
    expect(
      AuthCopy.loginSubtitle(AppConfig.appName),
      '\u4f7f\u7528\u624b\u673a\u53f7\u548c\u5bc6\u7801\u8fdb\u5165\u4fe1\u606f\u5e73\u6743',
    );
    expect(
      AuthCopy.registerTitle(AppConfig.appName),
      '\u521b\u5efa\u8d26\u53f7',
    );
    expect(
      AuthCopy.registerSubtitle(AppConfig.appName),
      '\u7528\u624b\u673a\u53f7\u521b\u5efa\u4fe1\u606f\u5e73\u6743\u8d26\u53f7',
    );
    expect(
      AuthCopy.resetPasswordSubtitle(AppConfig.appName),
      '\u901a\u8fc7\u77ed\u4fe1\u9a8c\u8bc1\u7801\u6062\u590d${AppConfig.appName}\u8bbf\u95ee\u6743\u9650',
    );
  });

  test('brand panel copy is frozen to approved campaign', () {
    expect(AuthCopy.loginBrandEyebrow(AppConfig.appName), '信息平权');
    expect(
      AuthCopy.loginBrandTitle(AppConfig.appName),
      '\u4fe1\u606f\u5e73\u6743',
    );
    expect(
      AuthCopy.loginBrandDescription,
      '\u8ba9\u5168\u5929\u4e0b\u7684\u4eba\u6ca1\u6709\u4fe1\u606f\u5dee',
    );
    expect(AuthCopy.loginBrandHighlights, <String>[
      '\u771f\u5b9e\u4fe1\u606f\u66f4\u5feb\u62b5\u8fbe',
      '\u7edf\u4e00\u53ef\u4fe1\u5165\u53e3',
      '\u684c\u9762 / \u79fb\u52a8 / \u7f51\u9875\u7aef\u4e00\u81f4\u4f53\u9a8c',
    ]);
    expect(
      AuthCopy.registerBrandTitle(AppConfig.appName),
      '\u4fe1\u606f\u5e73\u6743',
    );
    expect(
      AuthCopy.resetBrandTitle(AppConfig.appName),
      '\u4fe1\u606f\u5e73\u6743',
    );
  });

  test('login action spot checks stay stable', () {
    expect(AuthCopy.loginButton, '\u767b\u5f55');
    expect(AuthCopy.forgotPasswordEntry, '\u5fd8\u8bb0\u5bc6\u7801');
  });
}
