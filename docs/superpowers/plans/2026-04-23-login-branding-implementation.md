# Login Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the auth entry experience to `信息平权` with a flagship premium login layout while keeping all verified auth behavior unchanged.

**Architecture:** Keep the existing `AuthPageScaffold` split/stacked shell, centralize the new brand contract in `AppConfig` and `AuthCopy`, then restyle the shell with a navy-and-gold premium treatment that makes the brand panel visually dominant on desktop. Protect the change with focused auth widget tests first, then finish with Windows smoke verification.

**Tech Stack:** Flutter, flutter_test, Riverpod, Material 3

---

## Workspace Reality

- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` does not currently contain `.git` metadata on this machine.
- Replace commit steps with explicit verification checkpoints. If the real repository metadata is restored later, commit after each task using the checkpoint summary in this plan.

## File Structure

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\core\config\app_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\config\app_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\app\app.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_copy.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_experience_tokens.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_page_scaffold.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_copy_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_login_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_page_scaffold_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_register_reset_page_test.dart`

## Verification Commands

- Focused copy tests:
  - `flutter test test/modules/auth/auth_copy_test.dart`
- Focused widget tests:
  - `flutter test test/modules/auth/auth_login_page_test.dart`
  - `flutter test test/modules/auth/auth_page_scaffold_test.dart`
  - `flutter test test/modules/auth/auth_register_reset_page_test.dart`
- Combined auth branding sweep:
  - `flutter test test/modules/auth/auth_copy_test.dart test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_page_scaffold_test.dart test/modules/auth/auth_register_reset_page_test.dart`
- Windows smoke launch:
  - `flutter run -d windows --no-resident`
- If Windows smoke fails with a locked plugin DLL:
  - `Get-Process wukong_im_app -ErrorAction SilentlyContinue | Stop-Process -Force`

### Task 1: Freeze The New 品牌 Contract In Tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_copy_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_login_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_page_scaffold_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_register_reset_page_test.dart`

- [ ] **Step 1: Rewrite the copy test to lock the approved brand strings before touching production code**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/app_config.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_copy.dart';

void main() {
  test('auth copy exposes the approved 信息平权 branding contract', () {
    expect(AppConfig.appName, '信息平权');
    expect(AuthCopy.loginTitle(AppConfig.appName), '欢迎登录');
    expect(
      AuthCopy.loginSubtitle(AppConfig.appName),
      '使用手机号和密码进入${AppConfig.appName}',
    );
    expect(AuthCopy.registerTitle(AppConfig.appName), '创建账号');
    expect(
      AuthCopy.registerSubtitle(AppConfig.appName),
      '用手机号创建${AppConfig.appName}账号',
    );
    expect(
      AuthCopy.resetPasswordSubtitle(AppConfig.appName),
      '通过短信验证码恢复${AppConfig.appName}访问权限',
    );
    expect(AuthCopy.loginBrandEyebrow(AppConfig.appName), 'INFORMATION EQUITY');
    expect(AuthCopy.loginBrandTitle(AppConfig.appName), '信息平权');
    expect(AuthCopy.loginBrandDescription, '让全天下的人没有信息差');
    expect(
      AuthCopy.loginBrandHighlights,
      const <String>[
        '真实信息更快抵达',
        '统一可信入口',
        '桌面 / 移动 / Web 一致体验',
      ],
    );
    expect(AuthCopy.registerBrandTitle(AppConfig.appName), '信息平权');
    expect(AuthCopy.resetBrandTitle(AppConfig.appName), '信息平权');
    expect(AuthCopy.loginButton, '登录');
    expect(AuthCopy.forgotPasswordEntry, '忘记密码');
  });
}
```

- [ ] **Step 2: Tighten the login-page widget test around the new flagship copy**

```dart
testWidgets('renders login within the 信息平权 flagship auth panel on desktop viewport', (
  tester,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1366, 900));

  await pumpLoginPage(tester);

  expect(find.byKey(const ValueKey('auth-brand-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
  expect(find.text('欢迎登录'), findsOneWidget);
  expect(find.text('信息平权'), findsOneWidget);
  expect(find.text('让全天下的人没有信息差'), findsOneWidget);
  expect(
    find.text('使用手机号和密码进入${AppConfig.appName}'),
    findsOneWidget,
  );
  expect(find.text('真实信息更快抵达'), findsOneWidget);
  expect(find.text('统一可信入口'), findsOneWidget);
  expect(find.text('桌面 / 移动 / Web 一致体验'), findsOneWidget);
  expect(find.byKey(loginPrimaryActionKey), findsOneWidget);
  expect(find.byKey(const ValueKey('auth_login_phone_field')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('auth_login_password_field')),
    findsOneWidget,
  );
});
```

- [ ] **Step 3: Update scaffold and register/reset widget tests to reflect the new premium split ratio and shared brand shell**

```dart
testWidgets('AuthPageScaffold gives the brand panel visual priority on desktop', (
  tester,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 960));

  await tester.pumpWidget(
    const MaterialApp(
      home: AuthPageScaffold(
        title: '欢迎登录',
        pageLabel: '欢迎回来',
        brandEyebrow: 'INFORMATION EQUITY',
        brandTitle: '信息平权',
        brandDescription: '让全天下的人没有信息差',
        brandHighlights: <String>[
          '真实信息更快抵达',
          '统一可信入口',
          '桌面 / 移动 / Web 一致体验',
        ],
        body: SizedBox(height: 320, child: Placeholder()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final brandFinder = find.byKey(const ValueKey<String>('auth-brand-panel'));
  final formFinder = find.byKey(const ValueKey<String>('auth-form-panel'));
  final brandWidth = tester.getSize(brandFinder).width;
  final formWidth = tester.getSize(formFinder).width;

  expect(brandFinder, findsOneWidget);
  expect(formFinder, findsOneWidget);
  expect(brandWidth, greaterThan(formWidth));
  expect(brandWidth / formWidth, lessThan(1.35));
  expect(find.text('让全天下的人没有信息差'), findsOneWidget);
  expect(find.text('桌面 / 移动 / Web 一致体验'), findsOneWidget);
});

testWidgets('register and reset pages still render inside the shared 信息平权 shell', (
  tester,
) async {
  final repository = _RecordingAuthRepository();

  await _pumpRegisterPage(
    tester,
    repository: repository,
    capabilities: const AppRuntimeCapabilities(
      webLoginUrl: '',
      webLoginReachable: false,
      webLoginStatusMessage: 'disabled',
      registerInviteEnabled: true,
      registerInviteRequired: true,
    ),
  );

  expect(find.text('创建账号'), findsOneWidget);
  expect(find.text('信息平权'), findsOneWidget);
  expect(find.text('让全天下的人没有信息差'), findsOneWidget);

  await _pumpResetPage(tester, repository: repository);

  expect(find.text(AuthCopy.resetPasswordTitle), findsOneWidget);
  expect(
    find.text('通过短信验证码恢复${AppConfig.appName}访问权限'),
    findsOneWidget,
  );
});
```

- [ ] **Step 4: Run the auth tests to prove the new contract fails before implementation**

Run: `flutter test test/modules/auth/auth_copy_test.dart test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_page_scaffold_test.dart test/modules/auth/auth_register_reset_page_test.dart`

Expected: FAIL with old `WuKongIM` copy, old warm-shell expectations, or missing `信息平权` strings.

- [ ] **Step 5: Verification checkpoint**

Checkpoint:
- failing tests now describe the exact desired brand contract
- no production code changed yet
- the plan now has a hard red bar for copy, shell ratio, and login-page visibility

### Task 2: Rename The App Surface And Centralize The New Auth Copy

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\core\config\app_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\config\app_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\app\app.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_copy.dart`

- [ ] **Step 1: Change the app-name constants and app window title to 信息平权**

```dart
// lib/core/config/app_config.dart
class AppConfig {
  AppConfig._();

  static const String appName = '信息平权';
  static const String appVersion = '1.0.0';
  // ...
}

// lib/wukong_base/config/app_config.dart
class AppConfig {
  static const String appName = '信息平权';
  // ...
}

// lib/app/app.dart
import '../core/config/app_config.dart';

return MaterialApp.router(
  title: AppConfig.appName,
  debugShowCheckedModeBanner: false,
  // ...
);
```

- [ ] **Step 2: Replace the current auth branding helpers with one shared premium brand contract**

```dart
class AuthCopy {
  AuthCopy._();

  static const String brandEyebrow = 'INFORMATION EQUITY';
  static const String brandTitle = '信息平权';
  static const String brandDescription = '让全天下的人没有信息差';
  static const List<String> brandHighlights = <String>[
    '真实信息更快抵达',
    '统一可信入口',
    '桌面 / 移动 / Web 一致体验',
  ];

  static String loginTitle(String appName) => '欢迎登录';
  static String registerTitle(String appName) => '创建账号';

  static String loginSubtitle(String appName) => '使用手机号和密码进入$appName';
  static String registerSubtitle(String appName) => '用手机号创建$appName账号';
  static String resetPasswordSubtitle(String appName) =>
      '通过短信验证码恢复$appName访问权限';

  static String loginBrandEyebrow(String appName) => brandEyebrow;
  static String registerBrandEyebrow(String appName) => brandEyebrow;
  static String resetBrandEyebrow(String appName) => brandEyebrow;

  static String loginBrandTitle(String appName) => brandTitle;
  static String registerBrandTitle(String appName) => brandTitle;
  static String resetBrandTitle(String appName) => brandTitle;

  static const String loginBrandDescription = brandDescription;
  static const String registerBrandDescription = brandDescription;
  static const String resetBrandDescription = brandDescription;

  static const List<String> loginBrandHighlights = brandHighlights;
  static const List<String> registerBrandHighlights = brandHighlights;
  static const List<String> resetBrandHighlights = brandHighlights;

  static const String registerNicknameHint = '请输入昵称（选填）';
  static const String registerNicknameHelper =
      '显示用昵称，不作为登录账号。';
}
```

- [ ] **Step 3: Run the copy and route-adjacent auth tests that should pass after the copy rewrite**

Run:
- `flutter test test/modules/auth/auth_copy_test.dart`
- `flutter test test/modules/auth/auth_register_reset_page_test.dart`

Expected: PASS, while `auth_page_scaffold_test.dart` may still fail because the visual hierarchy has not been implemented yet.

- [ ] **Step 4: Verification checkpoint**

Checkpoint:
- app-visible auth naming is now sourced from `信息平权`
- touched auth strings are clean UTF-8 text, not mojibake escapes
- login/register/reset pages all share one brand contract through `AuthCopy`

### Task 3: Restyle The Shared Auth Shell To Match The Flagship Premium Direction

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_experience_tokens.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\auth\presentation\widgets\auth_page_scaffold.dart`

- [ ] **Step 1: Introduce separate dark-brand and light-form tokens so the shell can look premium without harming readability**

```dart
class AuthExperienceTokens {
  AuthExperienceTokens._();

  static const double desktopStageMaxWidth = 1220;
  static const double pageTopPadding = 34;
  static const double pageBottomPadding = 30;

  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(30, 32, 30, 30);
  static const EdgeInsets brandPanelPadding = EdgeInsets.fromLTRB(40, 42, 36, 36);
  static const EdgeInsets mobileBrandHeaderPadding = EdgeInsets.fromLTRB(22, 24, 22, 20);
  static const double stageShellRadius = 42;

  static const Color stageBackgroundTop = Color(0xFF06111F);
  static const Color stageBackgroundBottom = Color(0xFF0A1728);
  static const Color stageGlowPrimary = Color(0x263B6FB8);
  static const Color stageGlowSecondary = Color(0x1DB89457);
  static const Color stageGlowTertiary = Color(0x14324463);
  static const Color stageShellTop = Color(0xFF0E1B2D);
  static const Color stageShellBottom = Color(0xFF13233A);
  static const Color stageShellBorder = Color(0x335E7EA7);

  static const Color panelBackground = Color(0xFFF7F9FC);
  static const Color panelBorder = Color(0x1F91A4BA);
  static const Color panelInk = Color(0xFF162233);
  static const Color panelMuted = Color(0xFF667588);

  static const Color brandPanelBackground = Color(0xFF0A1626);
  static const Color brandPanelOverlay = Color(0x142B4264);
  static const Color brandInk = Color(0xFFF5F7FB);
  static const Color brandMuted = Color(0xFFD0D9E6);
  static const Color brandAccent = Color(0xFFD2A866);
  static const Color brandAccentStrong = Color(0xFFE6C88E);
  static const Color brandChipBackground = Color(0x12324667);
  static const Color brandChipBorder = Color(0x337E9FCA);

  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color inputHint = Color(0xFF738295);
  static const Color inputText = panelInk;
  static const Color inputBorder = Color(0x33485D77);
  static const Color inputBorderFocus = Color(0xFFD2A866);
}
```

- [ ] **Step 2: Make the desktop brand panel wider and restyle the brand block into the approved eyebrow-title-slogan-chip hierarchy**

```dart
// In _buildStageShell()
child: useDesktopSplit
    ? Row(
        children: <Widget>[
          Expanded(flex: 11, child: _buildBrandPanel(compact: false)),
          Expanded(flex: 9, child: _buildFormPanel(compact: false)),
        ],
      )
    : showStackedBranding
    ? Column(
        children: <Widget>[
          _buildMobileBrandHeader(compact: compact),
          _buildFormPanel(compact: compact),
        ],
      )
    : Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxPanelWidth),
          child: _buildFormPanel(compact: compact),
        ),
      );

// In _buildBrandPanel()
return Container(
  key: const ValueKey<String>(AuthExperienceTokens.brandPanelKey),
  padding: AuthExperienceTokens.brandPanelPadding,
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        AuthExperienceTokens.brandPanelBackground,
        AuthExperienceTokens.stageShellBottom,
      ],
    ),
    border: Border(
      right: BorderSide(
        color: AuthExperienceTokens.stageShellBorder.withOpacity(0.82),
      ),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (resolvedEyebrow.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AuthExperienceTokens.brandPanelOverlay,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuthExperienceTokens.brandChipBorder),
          ),
          child: Text(
            resolvedEyebrow,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: AuthExperienceTokens.brandAccentStrong,
            ),
          ),
        ),
        SizedBox(height: compact ? 24 : 30),
      ],
      if (resolvedTitle.isNotEmpty)
        Text(
          resolvedTitle,
          style: TextStyle(
            fontFamily: WKFontFamily.title,
            fontSize: compact ? 34 : 50,
            height: 1.04,
            fontWeight: FontWeight.w800,
            color: AuthExperienceTokens.brandInk,
          ),
        ),
      if (resolvedDescription.isNotEmpty) ...[
        SizedBox(height: compact ? 12 : 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            resolvedDescription,
            maxLines: compact ? 2 : 3,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: compact ? 15 : 18,
              height: 1.6,
              color: AuthExperienceTokens.brandMuted,
            ),
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        Container(
          width: compact ? 88 : 120,
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AuthExperienceTokens.brandAccentStrong,
                Color(0x00E6C88E),
              ],
            ),
          ),
        ),
      ],
      if (!compact) const Spacer(),
      if (visibleHighlights.isNotEmpty) ...[
        SizedBox(height: compact ? 18 : 26),
        Wrap(
          spacing: 10,
          runSpacing: AuthExperienceTokens.brandHighlightSpacing,
          children: [
            for (final item in visibleHighlights)
              _BrandHighlightChip(label: item),
          ],
        ),
      ],
    ],
  ),
);
```

- [ ] **Step 3: Keep the form panel readable with separate panel text colors and a compact mobile header that still shows the slogan**

```dart
// In _buildMobileBrandHeader()
Text(
  resolvedTitle,
  style: TextStyle(
    fontFamily: WKFontFamily.title,
    fontSize: compact ? 26 : 30,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AuthExperienceTokens.brandInk,
  ),
),
Text(
  resolvedDescription,
  maxLines: compact ? 2 : 3,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    fontFamily: WKFontFamily.primary,
    fontSize: 14,
    height: 1.5,
    color: AuthExperienceTokens.brandMuted,
  ),
),

// In _buildFormPanel()
Text(
  title,
  style: TextStyle(
    fontFamily: WKFontFamily.title,
    fontSize: compact ? 28 : 32,
    fontWeight: FontWeight.w700,
    color: AuthExperienceTokens.panelInk,
  ),
),
Text(
  subtitle!,
  style: TextStyle(
    fontFamily: WKFontFamily.primary,
    fontSize: compact ? 13 : 14,
    height: 1.5,
    color: AuthExperienceTokens.panelMuted,
  ),
),

// In _BrandHighlightChip()
child: Text(
  label,
  style: const TextStyle(
    fontFamily: WKFontFamily.primary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AuthExperienceTokens.brandInk,
  ),
),
```

- [ ] **Step 4: Run the focused auth widget tests until the new shell contract is green**

Run:
- `flutter test test/modules/auth/auth_login_page_test.dart`
- `flutter test test/modules/auth/auth_page_scaffold_test.dart`
- `flutter test test/modules/auth/auth_register_reset_page_test.dart`

Expected: PASS with the wider desktop brand panel, visible slogan, and unchanged auth controls.

- [ ] **Step 5: Verification checkpoint**

Checkpoint:
- desktop login now clearly prioritizes the left brand panel
- the navy-and-gold shell is in place without breaking form readability
- compact/mobile auth still renders without overflow

### Task 4: Finish With Full Auth Verification And Windows Smoke

**Files:**
- Modify: none
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_copy_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_login_page_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_page_scaffold_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\auth\auth_register_reset_page_test.dart`

- [ ] **Step 1: Run the combined auth branding suite**

Run: `flutter test test/modules/auth/auth_copy_test.dart test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_page_scaffold_test.dart test/modules/auth/auth_register_reset_page_test.dart`

Expected: PASS for all four files.

- [ ] **Step 2: Launch the Windows desktop build for real visual validation**

Run: `flutter run -d windows --no-resident`

Expected: app launches to the login page with the `信息平权` brand title, the slogan `让全天下的人没有信息差`, and no startup crash.

- [ ] **Step 3: If Windows launch fails because a stale process locked a DLL, clear the process and retry once**

```powershell
Get-Process wukong_im_app -ErrorAction SilentlyContinue | Stop-Process -Force
flutter run -d windows --no-resident
```

Expected: the second launch succeeds without a plugin lock error.

- [ ] **Step 4: Verification checkpoint**

Checkpoint:
- focused auth tests are green
- Windows app launches to the branded login screen
- auth behavior remains unchanged while the presentation reflects `信息平权`
