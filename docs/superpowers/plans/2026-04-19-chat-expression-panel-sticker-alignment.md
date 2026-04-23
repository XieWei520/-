# Chat Expression Panel / Sticker Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Android-aligned integrated expression panel to Flutter chat, including bundled local sticker packs, a new `WKStickerContent` message type, unified emoji/sticker/GIF browsing, and resilient sticker rendering fallbacks.

**Architecture:** Extend the local SDK first so sticker messages are first-class content instead of being forced through `WKGifContent`, then add a registry-driven expression layer in the app that can build one panel from emoji groups, bundled sticker packs, recents, and GIF search. Keep the existing `ChatPageShell` orchestration and `ChatSceneGateway` send path, but route emoji, sticker, and GIF taps through distinct content builders inside the same panel shell.

**Tech Stack:** Flutter, Dart, Riverpod, local path dependency `wukongimfluttersdk`, widget tests, unit tests, bundled `.webp` assets, SharedPreferences-backed recents, RobotService GIF search.

---

## Implementation Notes

This checkout is still treated as a non-Git workspace in the Codex app context. Keep the commit steps in the document for workflow completeness, but leave them unchecked until the workspace is reopened with `.git` metadata.

This feature spans two codebases inside the same local workspace:

- App: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app`
- Local SDK dependency: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master`

Do not skip the SDK task. `wukong_im_app` already imports `WKGifContent`, `WKTextContent`, and `WKRichTextContent` directly from the local SDK, so `WKStickerContent` must live there too or the app-side plan will dead-end at the type boundary.

## File Structure Map

**Create**

- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\model\wk_sticker_content.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\manifest.json`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\group.webp`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\other.webp`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\reply.webp`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\typing.webp`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\voice.webp`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_models.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_recent_store.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_sticker_pack_loader.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_registry.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_gif_panel_service.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\widgets\chat_expression_panel.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_sticker_content_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_registry_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_panel_test.dart`

**Modify**

- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\type\const.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\wkim.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\pubspec.yaml`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\msg_content_type.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_composer_controller.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_scene_providers.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\widgets\chat_emoji_panel.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_content_preview.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_composer_controller_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_page_android_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart`

**Responsibilities**

- `wk_sticker_content.dart`: define the new sticker message payload used by the app and SDK parser.
- `const.dart` and `wkim.dart`: register `WkMessageContentType.sticker` and make incoming/outgoing sticker payloads decode into `WKStickerContent`.
- `chat_expression_models.dart`: shared model types for panel categories, sticker manifests, recent items, and unified panel selections.
- `chat_expression_recent_store.dart`: persist mixed recent emoji/sticker/GIF selections by logical keys instead of file paths.
- `chat_sticker_pack_loader.dart`: load bundled sample sticker packs from manifest JSON and expose cached sticker lookups.
- `chat_expression_registry.dart`: combine recent items, Android emoji groups, bundled sticker packs, and the GIF entry into one bottom-strip snapshot.
- `chat_gif_panel_service.dart`: bridge `RobotService.searchGifs()` into a focused panel-facing API.
- `chat_expression_panel.dart`: render the single expression shell with internal category switching and category-specific content bodies.
- `chat_page_shell.dart`: replace the old face-panel branch with the integrated expression panel and route emoji/sticker/GIF taps through their correct send paths.
- `message_content_preview.dart` and `message_bubble.dart`: surface `[贴纸]` previews and render sticker message bubbles with animation -> preview -> placeholder -> text fallback.

### Task 1: Add `WKStickerContent` to the local SDK and app preview pipeline

**Files:**

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\model\wk_sticker_content.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\type\const.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\wkim.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\msg_content_type.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_content_preview.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_sticker_content_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart`

- [ ] **Step 1: Add failing SDK round-trip and preview tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/message_content_preview.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('WKStickerContent round trips and exposes sticker summary text', () {
    final content = WKStickerContent(
      packId: 'android_sample_motion',
      stickerId: 'typing',
      packVersion: 1,
      title: 'Typing',
      mimeType: 'image/webp',
      width: 512,
      height: 512,
      loopCount: 0,
      previewKey: 'assets/stickers/sample_pack/typing.webp',
      animationKey: 'assets/stickers/sample_pack/typing.webp',
      fallbackText: '[贴纸]',
    );

    final decoded =
        WKStickerContent().decodeJson(content.encodeJson()) as WKStickerContent;

    expect(decoded.packId, 'android_sample_motion');
    expect(decoded.stickerId, 'typing');
    expect(decoded.previewKey, 'assets/stickers/sample_pack/typing.webp');
    expect(decoded.animationKey, 'assets/stickers/sample_pack/typing.webp');
    expect(decoded.displayText(), '[贴纸]');
    expect(decoded.searchableWord(), '[贴纸]');
  });

  test('resolveMessagePreview returns sticker label for typed sticker content', () {
    final message = WKMsg()
      ..contentType = WkMessageContentType.sticker
      ..messageContent = WKStickerContent(
        packId: 'android_sample_motion',
        stickerId: 'typing',
        fallbackText: '[贴纸]',
      );

    final preview = resolveMessagePreview(message);

    expect(preview.text, '[贴纸]');
    expect(preview.isSystemNotice, isFalse);
  });
}
```

```dart
test('resolveStructuredMessagePreview localizes sticker payload label', () {
  final preview = resolveStructuredMessagePreview(
    '{"type":${WkMessageContentType.sticker},"packId":"android_sample_motion","stickerId":"typing"}',
  );

  expect(preview.text, '[贴纸]');
  expect(preview.isSystemNotice, isFalse);
});
```

- [ ] **Step 2: Run the preview tests and verify they fail before the SDK type exists**

Run: `flutter test test/modules/chat/chat_sticker_content_test.dart test/modules/chat/message_content_preview_test.dart`

Expected: FAIL because `WKStickerContent` and `WkMessageContentType.sticker` do not exist yet.

- [ ] **Step 3: Implement `WKStickerContent` inside the local SDK and register it**

```dart
import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class WKStickerContent extends WKMediaMessageContent {
  String packId;
  String stickerId;
  int packVersion;
  String title;
  String mimeType;
  int width;
  int height;
  int loopCount;
  String previewKey;
  String animationKey;
  String fallbackText;

  WKStickerContent({
    this.packId = '',
    this.stickerId = '',
    this.packVersion = 0,
    this.title = '',
    this.mimeType = '',
    this.width = 0,
    this.height = 0,
    this.loopCount = 0,
    this.previewKey = '',
    this.animationKey = '',
    this.fallbackText = '[贴纸]',
  }) {
    contentType = WkMessageContentType.sticker;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return <String, dynamic>{
      'packId': packId,
      'stickerId': stickerId,
      'packVersion': packVersion,
      'title': title,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'loopCount': loopCount,
      'previewKey': previewKey,
      'animationKey': animationKey,
      'fallbackText': fallbackText,
      'url': url,
      'localPath': localPath,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    packId = readString(json, 'packId');
    stickerId = readString(json, 'stickerId');
    packVersion = readInt(json, 'packVersion');
    title = readString(json, 'title');
    mimeType = readString(json, 'mimeType');
    width = readInt(json, 'width');
    height = readInt(json, 'height');
    loopCount = readInt(json, 'loopCount');
    previewKey = readString(json, 'previewKey');
    animationKey = readString(json, 'animationKey');
    fallbackText = readString(json, 'fallbackText');
    url = readString(json, 'url');
    localPath = readString(json, 'localPath');
    return this;
  }

  @override
  String displayText() {
    return fallbackText.trim().isEmpty ? '[贴纸]' : fallbackText.trim();
  }

  @override
  String searchableWord() {
    return displayText();
  }
}
```

```dart
class WkMessageContentType {
  static const unknown = -1;
  static const text = 1;
  static const image = 2;
  static const gif = 3;
  static const voice = 4;
  static const video = 5;
  static const location = 6;
  static const card = 7;
  static const file = 8;
  static const richText = 14;
  static const screenshot = 20;
  static const sticker = 21;
  static const contentFormatError = 97;
  static const insideMsg = 99;
}
```

```dart
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';

messageManager.registerMsgContent(WkMessageContentType.sticker, (dynamic data) {
  return WKStickerContent().decodeJson(data);
});
```

- [ ] **Step 4: Teach the app-side preview helpers about the new sticker type**

```dart
class MsgContentType {
  MsgContentType._();

  static const int text = 1;
  static const int image = 2;
  static const int gif = 3;
  static const int voice = 4;
  static const int video = 5;
  static const int location = 6;
  static const int card = 7;
  static const int file = 8;
  static const int richText = 14;
  static const int screenshot = 20;
  static const int sticker = 21;
  static const int sensitiveWord = -10;
  static const int unknown = 0;
}
```

```dart
const String _stickerMessageLabel = '[贴纸]';

MessagePreviewData resolveMessagePreview(
  WKMsg message, {
  String fallback = _messageFallback,
}) {
  final content = resolveVisibleMessageContent(message);
  switch (message.contentType) {
    case WkMessageContentType.text:
      final rawText = resolveVisibleTextMessage(
        message,
        fallback: _textMessageFallback,
      );
      return MessagePreviewData(
        text: rawText.isNotEmpty ? rawText : _textMessageFallback,
      );
    case WkMessageContentType.gif:
      return const MessagePreviewData(text: _gifMessageLabel);
    case WkMessageContentType.sticker:
      return const MessagePreviewData(text: _stickerMessageLabel);
    case MsgContentType.richText:
      final summary = summarizeMessageContent(
        content,
        fallback: _richTextMessageLabel,
      ).trim();
      return MessagePreviewData(
        text: summary.isNotEmpty ? summary : _richTextMessageLabel,
      );
    default:
      final structuredUnknown = _resolveUnknownStructuredPreview(
        message,
        fallback: fallback,
      );
      if (structuredUnknown != null) {
        return structuredUnknown;
      }
      final summary = summarizeMessageContent(content, fallback: '').trim();
      if (summary.isNotEmpty) {
        return MessagePreviewData(text: summary);
      }
      return resolveStructuredMessagePreview(
        message.content,
        fallback: fallback,
      );
  }
}

String _resolveTypedPayloadText(Map<String, dynamic> payload) {
  final type = int.tryParse(payload['type']?.toString() ?? '');
  switch (type) {
    case WkMessageContentType.gif:
      return _gifMessageLabel;
    case WkMessageContentType.sticker:
      return _stickerMessageLabel;
    case MsgContentType.richText:
      final text = payload['content']?.toString().trim() ?? '';
      return text.isNotEmpty ? text : _richTextMessageLabel;
    default:
      return '';
  }
}
```

- [ ] **Step 5: Re-run the focused tests and verify the new sticker type is wired end-to-end**

Run: `flutter test test/modules/chat/chat_sticker_content_test.dart test/modules/chat/message_content_preview_test.dart`

Expected: PASS with `[贴纸]` summary behavior for typed and structured sticker messages.

- [ ] **Step 6: Commit**

```bash
git add ..\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\model\wk_sticker_content.dart ..\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\type\const.dart ..\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\wkim.dart lib\wukong_base\msg\msg_content_type.dart lib\modules\chat\message_content_preview.dart test\modules\chat\chat_sticker_content_test.dart test\modules\chat\message_content_preview_test.dart
git commit -m "feat: add sticker content type and preview plumbing"
```

### Task 2: Bundle a local sample sticker pack and build the unified expression registry

**Files:**

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\pubspec.yaml`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\manifest.json`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\group.webp`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\other.webp`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\reply.webp`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\typing.webp`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\voice.webp`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_models.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_recent_store.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_sticker_pack_loader.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\expression\chat_expression_registry.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_registry_test.dart`

- [ ] **Step 1: Add a failing registry test that locks the internal category order and logical recent keys**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_models.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_registry.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_recent_store.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_sticker_pack_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('registry exposes recent, emoji groups, bundled stickers, and GIF inside one strip', () async {
    final registry = ChatExpressionRegistry(
      recentStore: ChatExpressionRecentStore(),
      stickerPackLoader: ChatStickerPackLoader(
        manifestPaths: const <String>[
          'assets/stickers/sample_pack/manifest.json',
        ],
      ),
    );

    final snapshot = await registry.load();

    expect(snapshot.categories.first.id, 'recent');
    expect(snapshot.categories.any((item) => item.kind == ChatExpressionKind.emoji), isTrue);
    expect(snapshot.categories.any((item) => item.kind == ChatExpressionKind.sticker), isTrue);
    expect(snapshot.categories.any((item) => item.kind == ChatExpressionKind.gif), isTrue);
  });

  test('recent records persist logical sticker keys instead of asset paths', () async {
    final store = ChatExpressionRecentStore();

    await store.save(const <ChatExpressionRecentRecord>[
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.sticker,
        categoryId: 'sticker:android_sample_motion',
        itemId: 'typing',
        displayText: '[贴纸]',
        previewKey: 'assets/stickers/sample_pack/typing.webp',
        animationKey: 'assets/stickers/sample_pack/typing.webp',
        gifUrl: '',
        width: 512,
        height: 512,
      ),
    ]);

    final loaded = await store.load();

    expect(loaded.single.logicalKey, 'sticker:android_sample_motion:typing');
    expect(loaded.single.categoryId, 'sticker:android_sample_motion');
    expect(loaded.single.itemId, 'typing');
  });
}
```

- [ ] **Step 2: Run the registry test and verify it fails before the manifest and loader exist**

Run: `flutter test test/modules/chat/chat_expression_registry_test.dart`

Expected: FAIL because the expression model, recent store, and sticker loader files do not exist yet.

- [ ] **Step 3: Create the bundled sticker assets and manifest**

Run:

```powershell
New-Item -ItemType Directory -Force 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack'
Copy-Item 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\imgs\group.webp' 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\group.webp'
Copy-Item 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\imgs\other.webp' 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\other.webp'
Copy-Item 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\imgs\reply.webp' 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\reply.webp'
Copy-Item 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\imgs\typing.webp' 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\typing.webp'
Copy-Item 'C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoAndroid-master\imgs\voice.webp' 'C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\assets\stickers\sample_pack\voice.webp'
```

```json
{
  "packId": "android_sample_motion",
  "packVersion": 1,
  "title": "Android Motion",
  "cover": "assets/stickers/sample_pack/group.webp",
  "stickers": [
    {
      "stickerId": "group",
      "title": "Group",
      "preview": "assets/stickers/sample_pack/group.webp",
      "animation": "assets/stickers/sample_pack/group.webp",
      "mimeType": "image/webp",
      "width": 512,
      "height": 512,
      "loopCount": 0,
      "fallbackText": "[贴纸]"
    },
    {
      "stickerId": "other",
      "title": "Other",
      "preview": "assets/stickers/sample_pack/other.webp",
      "animation": "assets/stickers/sample_pack/other.webp",
      "mimeType": "image/webp",
      "width": 512,
      "height": 512,
      "loopCount": 0,
      "fallbackText": "[贴纸]"
    },
    {
      "stickerId": "reply",
      "title": "Reply",
      "preview": "assets/stickers/sample_pack/reply.webp",
      "animation": "assets/stickers/sample_pack/reply.webp",
      "mimeType": "image/webp",
      "width": 512,
      "height": 512,
      "loopCount": 0,
      "fallbackText": "[贴纸]"
    },
    {
      "stickerId": "typing",
      "title": "Typing",
      "preview": "assets/stickers/sample_pack/typing.webp",
      "animation": "assets/stickers/sample_pack/typing.webp",
      "mimeType": "image/webp",
      "width": 512,
      "height": 512,
      "loopCount": 0,
      "fallbackText": "[贴纸]"
    },
    {
      "stickerId": "voice",
      "title": "Voice",
      "preview": "assets/stickers/sample_pack/voice.webp",
      "animation": "assets/stickers/sample_pack/voice.webp",
      "mimeType": "image/webp",
      "width": 512,
      "height": 512,
      "loopCount": 0,
      "fallbackText": "[贴纸]"
    }
  ]
}
```

- [ ] **Step 4: Add the asset entry and implement the shared expression models, recent store, loader, and registry**

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/emoji/
    - assets/emoji/android/
    - assets/stickers/
    - assets/icons/
    - assets/reference_ui/icons/
```

```dart
import 'package:meta/meta.dart';

enum ChatExpressionKind { emoji, sticker, gif }

@immutable
class ChatStickerDefinition {
  const ChatStickerDefinition({
    required this.packId,
    required this.stickerId,
    required this.title,
    required this.previewKey,
    required this.animationKey,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.loopCount,
    required this.fallbackText,
  });

  final String packId;
  final String stickerId;
  final String title;
  final String previewKey;
  final String animationKey;
  final String mimeType;
  final int width;
  final int height;
  final int loopCount;
  final String fallbackText;
}

@immutable
class ChatStickerPack {
  const ChatStickerPack({
    required this.packId,
    required this.packVersion,
    required this.title,
    required this.cover,
    required this.stickers,
  });

  final String packId;
  final int packVersion;
  final String title;
  final String cover;
  final List<ChatStickerDefinition> stickers;
}

@immutable
class ChatExpressionRecentRecord {
  const ChatExpressionRecentRecord({
    required this.kind,
    required this.categoryId,
    required this.itemId,
    required this.displayText,
    required this.previewKey,
    required this.animationKey,
    required this.gifUrl,
    required this.width,
    required this.height,
  });

  final ChatExpressionKind kind;
  final String categoryId;
  final String itemId;
  final String displayText;
  final String previewKey;
  final String animationKey;
  final String gifUrl;
  final int width;
  final int height;

  String get logicalKey => '${kind.name}:$categoryId:$itemId';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'categoryId': categoryId,
      'itemId': itemId,
      'displayText': displayText,
      'previewKey': previewKey,
      'animationKey': animationKey,
      'gifUrl': gifUrl,
      'width': width,
      'height': height,
    };
  }

  factory ChatExpressionRecentRecord.fromJson(Map<String, dynamic> json) {
    return ChatExpressionRecentRecord(
      kind: ChatExpressionKind.values.firstWhere(
        (item) => item.name == json['kind'],
      ),
      categoryId: json['categoryId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      displayText: json['displayText']?.toString() ?? '',
      previewKey: json['previewKey']?.toString() ?? '',
      animationKey: json['animationKey']?.toString() ?? '',
      gifUrl: json['gifUrl']?.toString() ?? '',
      width: int.tryParse(json['width']?.toString() ?? '') ?? 0,
      height: int.tryParse(json['height']?.toString() ?? '') ?? 0,
    );
  }
}

@immutable
class ChatExpressionCategory {
  const ChatExpressionCategory({
    required this.id,
    required this.kind,
    required this.label,
    required this.iconKey,
    required this.emojiTags,
    required this.stickers,
    required this.recents,
    this.isGif = false,
  });

  final String id;
  final ChatExpressionKind kind;
  final String label;
  final String iconKey;
  final List<String> emojiTags;
  final List<ChatStickerDefinition> stickers;
  final List<ChatExpressionRecentRecord> recents;
  final bool isGif;
}

@immutable
class ChatExpressionRegistrySnapshot {
  const ChatExpressionRegistrySnapshot({required this.categories});

  final List<ChatExpressionCategory> categories;
}
```

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_expression_models.dart';

class ChatExpressionRecentStore {
  static const String _storageKey = 'chat_expression_recent_v1';
  static const int _maxItems = 30;

  Future<List<ChatExpressionRecentRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? const <String>[];
    return rawList
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .map(ChatExpressionRecentRecord.fromJson)
        .toList(growable: false);
  }

  Future<void> save(List<ChatExpressionRecentRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      records
          .take(_maxItems)
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false),
    );
  }

  Future<void> remember(ChatExpressionRecentRecord nextRecord) async {
    final existing = await load();
    final deduped = <ChatExpressionRecentRecord>[
      nextRecord,
      for (final item in existing)
        if (item.logicalKey != nextRecord.logicalKey) item,
    ];
    await save(deduped);
  }
}
```

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'chat_expression_models.dart';

class ChatStickerPackLoader {
  ChatStickerPackLoader({
    this.manifestPaths = const <String>[
      'assets/stickers/sample_pack/manifest.json',
    ],
  });

  final List<String> manifestPaths;
  List<ChatStickerPack>? _cachedPacks;

  Future<List<ChatStickerPack>> load() async {
    if (_cachedPacks != null) {
      return _cachedPacks!;
    }
    final packs = <ChatStickerPack>[];
    for (final path in manifestPaths) {
      final raw = await rootBundle.loadString(path);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final stickers = (json['stickers'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (item) => ChatStickerDefinition(
              packId: json['packId']?.toString() ?? '',
              stickerId: item['stickerId']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              previewKey: item['preview']?.toString() ?? '',
              animationKey: item['animation']?.toString() ?? '',
              mimeType: item['mimeType']?.toString() ?? '',
              width: int.tryParse(item['width']?.toString() ?? '') ?? 0,
              height: int.tryParse(item['height']?.toString() ?? '') ?? 0,
              loopCount: int.tryParse(item['loopCount']?.toString() ?? '') ?? 0,
              fallbackText: item['fallbackText']?.toString() ?? '[贴纸]',
            ),
          )
          .toList(growable: false);
      packs.add(
        ChatStickerPack(
          packId: json['packId']?.toString() ?? '',
          packVersion: int.tryParse(json['packVersion']?.toString() ?? '') ?? 0,
          title: json['title']?.toString() ?? '',
          cover: json['cover']?.toString() ?? '',
          stickers: stickers,
        ),
      );
    }
    _cachedPacks = List<ChatStickerPack>.unmodifiable(packs);
    return _cachedPacks!;
  }
}
```

```dart
import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import 'chat_expression_models.dart';
import 'chat_expression_recent_store.dart';
import 'chat_sticker_pack_loader.dart';

class ChatExpressionRegistry {
  ChatExpressionRegistry({
    ChatExpressionRecentStore? recentStore,
    ChatStickerPackLoader? stickerPackLoader,
  }) : _recentStore = recentStore ?? ChatExpressionRecentStore(),
       _stickerPackLoader = stickerPackLoader ?? ChatStickerPackLoader();

  final ChatExpressionRecentStore _recentStore;
  final ChatStickerPackLoader _stickerPackLoader;

  Future<ChatExpressionRegistrySnapshot> load() async {
    final recents = await _recentStore.load();
    final packs = await _stickerPackLoader.load();

    final categories = <ChatExpressionCategory>[
      ChatExpressionCategory(
        id: 'recent',
        kind: ChatExpressionKind.emoji,
        label: 'Recent',
        iconKey: 'recent',
        emojiTags: const <String>[],
        stickers: const <ChatStickerDefinition>[],
        recents: recents,
      ),
      for (final groupId in androidEmojiCatalog.groupIds)
        ChatExpressionCategory(
          id: 'emoji:$groupId',
          kind: ChatExpressionKind.emoji,
          label: groupId,
          iconKey: 'emoji:$groupId',
          emojiTags: androidEmojiCatalog
              .entriesForGroup(groupId)
              .map((item) => item.tag)
              .toList(growable: false),
          stickers: const <ChatStickerDefinition>[],
          recents: const <ChatExpressionRecentRecord>[],
        ),
      for (final pack in packs)
        ChatExpressionCategory(
          id: 'sticker:${pack.packId}',
          kind: ChatExpressionKind.sticker,
          label: pack.title,
          iconKey: pack.cover,
          emojiTags: const <String>[],
          stickers: pack.stickers,
          recents: const <ChatExpressionRecentRecord>[],
        ),
      const ChatExpressionCategory(
        id: 'gif',
        kind: ChatExpressionKind.gif,
        label: 'GIF',
        iconKey: 'gif',
        emojiTags: <String>[],
        stickers: <ChatStickerDefinition>[],
        recents: <ChatExpressionRecentRecord>[],
        isGif: true,
      ),
    ];

    return ChatExpressionRegistrySnapshot(
      categories: List<ChatExpressionCategory>.unmodifiable(categories),
    );
  }

  Future<void> rememberEmoji(AndroidEmojiEntry entry) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.emoji,
        categoryId: 'emoji:${entry.groupId}',
        itemId: entry.tag,
        displayText: entry.tag,
        previewKey: entry.assetPath,
        animationKey: '',
        gifUrl: '',
        width: 0,
        height: 0,
      ),
    );
  }

  Future<void> rememberSticker(ChatStickerDefinition sticker) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.sticker,
        categoryId: 'sticker:${sticker.packId}',
        itemId: sticker.stickerId,
        displayText: sticker.fallbackText,
        previewKey: sticker.previewKey,
        animationKey: sticker.animationKey,
        gifUrl: '',
        width: sticker.width,
        height: sticker.height,
      ),
    );
  }

  Future<void> rememberGif({
    required String title,
    required String url,
    required int width,
    required int height,
  }) {
    return _recentStore.remember(
      ChatExpressionRecentRecord(
        kind: ChatExpressionKind.gif,
        categoryId: 'gif',
        itemId: title,
        displayText: 'GIF',
        previewKey: '',
        animationKey: '',
        gifUrl: url,
        width: width,
        height: height,
      ),
    );
  }

  Future<void> rememberRecent(ChatExpressionRecentRecord record) {
    return _recentStore.remember(record);
  }
}
```

- [ ] **Step 5: Run the registry test again and verify the unified category strip now exists in data**

Run: `flutter test test/modules/chat/chat_expression_registry_test.dart`

Expected: PASS with categories ordered as `recent -> emoji groups -> sticker packs -> gif`.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml assets/stickers/sample_pack lib/modules/chat/expression test/modules/chat/chat_expression_registry_test.dart
git commit -m "feat: add bundled sticker registry and sample pack"
```

### Task 3: Extend composer state and build the integrated expression panel shell

**Files:**

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_composer_controller.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_scene_providers.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\widgets\chat_emoji_panel.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_gif_panel_service.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\widgets\chat_expression_panel.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_panel_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_composer_controller_test.dart`

- [ ] **Step 1: Add failing controller and widget tests for the single-shell integrated panel**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_composer_controller.dart';

void main() {
  test('selectExpressionCategory keeps the face panel open while switching categories in place', () {
    final controller = ChatComposerController(
      channelId: 'u_expression_state',
      channelType: 1,
    );

    controller.toggleFacePanel(initialCategoryId: 'emoji:0');
    controller.selectExpressionCategory('sticker:android_sample_motion');

    expect(controller.state.showFacePanel, isTrue);
    expect(controller.state.activeExpressionCategoryId, 'sticker:android_sample_motion');

    controller.selectExpressionCategory('gif');

    expect(controller.state.showFacePanel, isTrue);
    expect(controller.state.activeExpressionCategoryId, 'gif');
  });
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_models.dart';
import 'package:wukong_im_app/modules/chat/chat_gif_panel_service.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_expression_panel.dart';

void main() {
  testWidgets('expression panel uses one shell and swaps content inside it', (tester) async {
    final snapshot = ChatExpressionRegistrySnapshot(
      categories: const <ChatExpressionCategory>[
        ChatExpressionCategory(
          id: 'recent',
          kind: ChatExpressionKind.emoji,
          label: 'Recent',
          iconKey: 'recent',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'emoji:0',
          kind: ChatExpressionKind.emoji,
          label: '0',
          iconKey: 'emoji:0',
          emojiTags: <String>['[微笑]'],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'sticker:android_sample_motion',
          kind: ChatExpressionKind.sticker,
          label: 'Android Motion',
          iconKey: 'assets/stickers/sample_pack/group.webp',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[
            ChatStickerDefinition(
              packId: 'android_sample_motion',
              stickerId: 'typing',
              title: 'Typing',
              previewKey: 'assets/stickers/sample_pack/typing.webp',
              animationKey: 'assets/stickers/sample_pack/typing.webp',
              mimeType: 'image/webp',
              width: 512,
              height: 512,
              loopCount: 0,
              fallbackText: '[贴纸]',
            ),
          ],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'gif',
          kind: ChatExpressionKind.gif,
          label: 'GIF',
          iconKey: 'gif',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
          isGif: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatExpressionPanel(
            snapshot: snapshot,
            activeCategoryId: 'emoji:0',
            gifResults: const <ChatGifPanelResult>[],
            gifErrorText: null,
            onCategorySelected: (_) {},
            onRecentSelected: (_) {},
            onEmojiSelected: (_) {},
            onStickerSelected: (_, _) {},
            onGifQueryChanged: (_) {},
            onGifSelected: (_) {},
            onBackspaceTap: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('chat-expression-panel-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('chat-expression-category-gif')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('chat-expression-emoji-grid')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the controller and widget tests and verify they fail before the new state fields exist**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_expression_panel_test.dart`

Expected: FAIL because `activeExpressionCategoryId`, `ChatGifPanelResult`, and `ChatExpressionPanel` do not exist yet.

- [ ] **Step 3: Add the composer state fields, provider wiring, reusable emoji grid body, GIF adapter, and the unified panel shell**

```dart
class ChatComposerState {
  const ChatComposerState({
    this.text = '',
    this.pendingReplyMessageId,
    this.pendingReplyPreview,
    this.pendingEditMessageId,
    this.pendingEditMessageSeq,
    this.pendingEditPreview,
    this.showVoiceInput = false,
    this.showFacePanel = false,
    this.showFunctionPanel = false,
    this.showFlamePanel = false,
    this.showRobotMenuPanel = false,
    this.activeExpressionCategoryId = 'emoji:0',
    this.expressionSearchQuery = '',
  });

  final String text;
  final String? pendingReplyMessageId;
  final String? pendingReplyPreview;
  final String? pendingEditMessageId;
  final int? pendingEditMessageSeq;
  final String? pendingEditPreview;
  final bool showVoiceInput;
  final bool showFacePanel;
  final bool showFunctionPanel;
  final bool showFlamePanel;
  final bool showRobotMenuPanel;
  final String activeExpressionCategoryId;
  final String expressionSearchQuery;

  ChatComposerState copyWith({
    String? text,
    String? pendingReplyMessageId,
    bool clearReply = false,
    String? pendingReplyPreview,
    String? pendingEditMessageId,
    int? pendingEditMessageSeq,
    String? pendingEditPreview,
    bool clearEdit = false,
    bool? showVoiceInput,
    bool? showFacePanel,
    bool? showFunctionPanel,
    bool? showFlamePanel,
    bool? showRobotMenuPanel,
    String? activeExpressionCategoryId,
    String? expressionSearchQuery,
  }) {
    return ChatComposerState(
      text: text ?? this.text,
      pendingReplyMessageId: clearReply
          ? null
          : (pendingReplyMessageId ?? this.pendingReplyMessageId),
      pendingReplyPreview: clearReply
          ? null
          : (pendingReplyPreview ?? this.pendingReplyPreview),
      pendingEditMessageId: clearEdit
          ? null
          : (pendingEditMessageId ?? this.pendingEditMessageId),
      pendingEditMessageSeq: clearEdit
          ? null
          : (pendingEditMessageSeq ?? this.pendingEditMessageSeq),
      pendingEditPreview: clearEdit
          ? null
          : (pendingEditPreview ?? this.pendingEditPreview),
      showVoiceInput: showVoiceInput ?? this.showVoiceInput,
      showFacePanel: showFacePanel ?? this.showFacePanel,
      showFunctionPanel: showFunctionPanel ?? this.showFunctionPanel,
      showFlamePanel: showFlamePanel ?? this.showFlamePanel,
      showRobotMenuPanel: showRobotMenuPanel ?? this.showRobotMenuPanel,
      activeExpressionCategoryId:
          activeExpressionCategoryId ?? this.activeExpressionCategoryId,
      expressionSearchQuery: expressionSearchQuery ?? this.expressionSearchQuery,
    );
  }
}

void toggleFacePanel({String? initialCategoryId}) {
  state = state.copyWith(
    showVoiceInput: false,
    showFacePanel: !state.showFacePanel,
    showFunctionPanel: false,
    showFlamePanel: false,
    showRobotMenuPanel: false,
    activeExpressionCategoryId:
        initialCategoryId ?? state.activeExpressionCategoryId,
  );
}

void selectExpressionCategory(String categoryId) {
  state = state.copyWith(
    showFacePanel: true,
    showFunctionPanel: false,
    showFlamePanel: false,
    showRobotMenuPanel: false,
    activeExpressionCategoryId: categoryId,
    expressionSearchQuery: categoryId == 'gif' ? state.expressionSearchQuery : '',
  );
}

void updateExpressionSearchQuery(String query) {
  state = state.copyWith(expressionSearchQuery: query);
}

void markSubmitSucceeded() {
  state = state.copyWith(
    text: '',
    clearReply: true,
    clearEdit: true,
    showVoiceInput: false,
    showFacePanel: false,
    showFunctionPanel: false,
    showFlamePanel: false,
    showRobotMenuPanel: false,
    expressionSearchQuery: '',
  );
}
```

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_gif_panel_service.dart';
import 'expression/chat_expression_registry.dart';

final chatExpressionRegistryProvider =
    Provider.autoDispose<ChatExpressionRegistry>((ref) {
      return ChatExpressionRegistry();
    });

final chatGifPanelServiceProvider = Provider.autoDispose<ChatGifPanelService>((
  ref,
) {
  return ChatGifPanelService();
});
```

```dart
import 'package:flutter/material.dart';

import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../../widgets/wk_colors.dart';

class ChatEmojiGridBody extends StatelessWidget {
  const ChatEmojiGridBody({
    super.key,
    required this.emojiTags,
    required this.onEmojiTap,
  });

  final List<String> emojiTags;
  final ValueChanged<AndroidEmojiEntry> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    final entries = emojiTags
        .map(androidEmojiCatalog.lookupByTag)
        .whereType<AndroidEmojiEntry>()
        .toList(growable: false);

    return GridView.builder(
      key: const ValueKey<String>('chat-expression-emoji-grid'),
      shrinkWrap: true,
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          key: ValueKey<String>('chat-expression-emoji-${entry.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onEmojiTap(entry),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: WKColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Image.asset(entry.assetPath, width: 28, height: 28),
            ),
          ),
        );
      },
    );
  }
}
```

```dart
import '../../data/models/chat_session.dart';
import '../../wukong_robot/models/robot.dart';
import '../../wukong_robot/robot_service.dart';

class ChatGifPanelResult {
  const ChatGifPanelResult({
    required this.url,
    required this.width,
    required this.height,
    required this.title,
  });

  final String url;
  final int width;
  final int height;
  final String title;
}

class ChatGifPanelService {
  ChatGifPanelService({RobotService? robotService})
      : _robotService = robotService ?? RobotService.instance;

  final RobotService _robotService;

  Future<List<ChatGifPanelResult>> search(
    String query, {
    required ChatSession session,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <ChatGifPanelResult>[];
    }

    final results = await _robotService.searchGifs(
      query: normalized,
      username: 'gif',
      channelId: session.channelId,
      channelType: session.channelType,
    );

    return results
        .map(
          (item) => ChatGifPanelResult(
            url: item.contentUrl?.trim() ?? '',
            width: (item.extraData['width'] as num?)?.toInt() ?? 0,
            height: (item.extraData['height'] as num?)?.toInt() ?? 0,
            title: item.id.trim(),
          ),
        )
        .where((item) => item.url.isNotEmpty)
        .toList(growable: false);
  }
}
```

```dart
import 'package:flutter/material.dart';

import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../chat_gif_panel_service.dart';
import '../expression/chat_expression_models.dart';
import 'chat_emoji_panel.dart';

class ChatExpressionPanel extends StatelessWidget {
  const ChatExpressionPanel({
    super.key,
    required this.snapshot,
    required this.activeCategoryId,
    required this.gifResults,
    required this.gifErrorText,
    required this.onCategorySelected,
    required this.onRecentSelected,
    required this.onEmojiSelected,
    required this.onStickerSelected,
    required this.onGifQueryChanged,
    required this.onGifSelected,
    required this.onBackspaceTap,
  });

  final ChatExpressionRegistrySnapshot snapshot;
  final String activeCategoryId;
  final List<ChatGifPanelResult> gifResults;
  final String? gifErrorText;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<ChatExpressionRecentRecord> onRecentSelected;
  final ValueChanged<AndroidEmojiEntry> onEmojiSelected;
  final void Function(String categoryId, ChatStickerDefinition sticker)
  onStickerSelected;
  final ValueChanged<String> onGifQueryChanged;
  final ValueChanged<ChatGifPanelResult> onGifSelected;
  final VoidCallback onBackspaceTap;

  @override
  Widget build(BuildContext context) {
    final activeCategory = snapshot.categories.firstWhere(
      (item) => item.id == activeCategoryId,
      orElse: () => snapshot.categories.first,
    );

    return Container(
      key: const ValueKey<String>('chat-expression-panel-shell'),
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Expanded(child: _buildBody(activeCategory)),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = snapshot.categories[index];
                return InkWell(
                  key: ValueKey<String>('chat-expression-category-${category.id}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onCategorySelected(category.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: category.id == activeCategory.id
                            ? const Color(0xFF1F67E8)
                            : const Color(0xFFE4E9F1),
                      ),
                    ),
                    child: Text(category.label),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChatExpressionCategory category) {
    if (category.id == 'recent') {
      return GridView.builder(
        key: const ValueKey<String>('chat-expression-recent-grid'),
        itemCount: category.recents.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final recent = category.recents[index];
          return InkWell(
            key: ValueKey<String>('chat-expression-recent-${recent.logicalKey}'),
            onTap: () => onRecentSelected(recent),
            child: recent.previewKey.isNotEmpty
                ? Image.asset(recent.previewKey, fit: BoxFit.contain)
                : Center(child: Text(recent.displayText)),
          );
        },
      );
    }

    if (category.isGif) {
      return Column(
        children: [
          TextField(
            key: const ValueKey<String>('chat-expression-gif-search-field'),
            onChanged: onGifQueryChanged,
            decoration: const InputDecoration(
              hintText: '搜索 GIF',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          if (gifErrorText != null && gifErrorText!.trim().isNotEmpty)
            Text(gifErrorText!, key: const ValueKey<String>('chat-expression-gif-error')),
          if (gifResults.isNotEmpty)
            Expanded(
              child: GridView.builder(
                key: const ValueKey<String>('chat-expression-gif-grid'),
                itemCount: gifResults.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final result = gifResults[index];
                  return InkWell(
                    key: ValueKey<String>('chat-expression-gif-item-$index'),
                    onTap: () => onGifSelected(result),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFF3F6FA)),
                      child: Center(child: Text('GIF')),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    if (category.kind == ChatExpressionKind.sticker) {
      return GridView.builder(
        key: const ValueKey<String>('chat-expression-sticker-grid'),
        itemCount: category.stickers.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final sticker = category.stickers[index];
          return InkWell(
            key: ValueKey<String>('chat-expression-sticker-${sticker.stickerId}'),
            onTap: () => onStickerSelected(category.id, sticker),
            child: Image.asset(sticker.previewKey, fit: BoxFit.contain),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: ChatEmojiGridBody(
            emojiTags: category.emojiTags,
            onEmojiTap: onEmojiSelected,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const ValueKey<String>('chat-expression-backspace'),
            onPressed: onBackspaceTap,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Re-run the controller and widget tests and verify the single-shell panel state now exists**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_expression_panel_test.dart`

Expected: PASS with one panel shell and in-place category switching.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_composer_controller.dart lib/modules/chat/chat_scene_providers.dart lib/modules/chat/chat_gif_panel_service.dart lib/modules/chat/widgets/chat_emoji_panel.dart lib/modules/chat/widgets/chat_expression_panel.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_expression_panel_test.dart
git commit -m "feat: add integrated expression panel shell"
```

### Task 4: Wire the integrated panel into `ChatPageShell` and split emoji, sticker, and GIF send paths

**Files:**

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_page_android_parity_test.dart`

- [ ] **Step 1: Add failing parity tests for sticker send and GIF send inside the same expression panel**

```dart
testWidgets('tapping a bundled sticker cell sends WKStickerContent', (tester) async {
  final gateway = _RecordingChatSceneGateway();

  await pumpChatPage(
    tester,
    channelId: 'u_panel_sticker_send',
    channelType: WKChannelType.personal,
    channelName: 'Sticker Send',
    overrides: <Override>[
      chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
    ],
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji')),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(
      const ValueKey<String>(
        'chat-expression-category-sticker:android_sample_motion',
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-expression-sticker-typing')),
  );
  await tester.pumpAndSettle();

  expect(gateway.sentContents.single, isA<WKStickerContent>());
  final content = gateway.sentContents.single as WKStickerContent;
  expect(content.packId, 'android_sample_motion');
  expect(content.stickerId, 'typing');
  expect(content.animationKey, 'assets/stickers/sample_pack/typing.webp');
});
```

```dart
testWidgets('GIF category search stays inside the same expression panel and sends WKGifContent', (tester) async {
  final gateway = _RecordingChatSceneGateway();
  final gifService = _FakeChatGifPanelService(
    results: const <ChatGifPanelResult>[
      ChatGifPanelResult(
        url: 'https://example.com/panel-cat.gif',
        width: 120,
        height: 120,
        title: 'cat',
      ),
    ],
  );

  await pumpChatPage(
    tester,
    channelId: 'u_panel_gif_send',
    channelType: WKChannelType.personal,
    channelName: 'GIF Send',
    overrides: <Override>[
      chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
      chatGifPanelServiceProvider.overrideWithValue(gifService),
    ],
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji')),
  );
  await tester.pumpAndSettle();

  final shellFinder = find.byKey(
    const ValueKey<String>('chat-expression-panel-shell'),
  );
  expect(shellFinder, findsOneWidget);

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-expression-category-gif')),
  );
  await tester.pumpAndSettle();

  expect(shellFinder, findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey<String>('chat-expression-gif-search-field')),
    'cat',
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-expression-gif-item-0')),
  );
  await tester.pumpAndSettle();

  expect(gateway.sentContents.single, isA<WKGifContent>());
  final content = gateway.sentContents.single as WKGifContent;
  expect(content.url, 'https://example.com/panel-cat.gif');
  expect(content.width, 120);
  expect(content.height, 120);
});

class _FakeChatGifPanelService extends ChatGifPanelService {
  _FakeChatGifPanelService({required this.results});

  final List<ChatGifPanelResult> results;

  @override
  Future<List<ChatGifPanelResult>> search(
    String query, {
    required ChatSession session,
  }) async {
    return results;
  }
}
```

- [ ] **Step 2: Run the parity tests and verify they fail before `ChatPageShell` uses the new panel**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`

Expected: FAIL because `ChatPageShell` still opens the old emoji-only panel and the GIF path is still outside the expression panel.

- [ ] **Step 3: Replace the old face panel branch with the integrated expression panel and route each item kind through its own send path**

```dart
Future<void> _handleStickerTap(
  ChatComposerController composerController,
  ChatExpressionRegistry registry,
  ChatStickerDefinition sticker,
) async {
  final content = WKStickerContent(
    packId: sticker.packId,
    stickerId: sticker.stickerId,
    packVersion: 1,
    title: sticker.title,
    mimeType: sticker.mimeType,
    width: sticker.width,
    height: sticker.height,
    loopCount: sticker.loopCount,
    previewKey: sticker.previewKey,
    animationKey: sticker.animationKey,
    fallbackText: sticker.fallbackText,
  );
  await _sendPickedContent(content, composerController);
  await registry.rememberSticker(sticker);
}

Future<void> _handlePanelGifTap(
  ChatComposerController composerController,
  ChatExpressionRegistry registry,
  ChatGifPanelResult result,
) async {
  final content = WKGifContent(width: result.width, height: result.height)
    ..url = result.url;
  await _sendPickedContent(content, composerController);
  await registry.rememberGif(
    title: result.title,
    url: result.url,
    width: result.width,
    height: result.height,
  );
}

Future<void> _handlePanelEmojiTap(
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
  ChatExpressionRegistry registry,
  AndroidEmojiEntry entry,
) async {
  _insertEmoji(entry.tag, composerController, mentionsController);
  await registry.rememberEmoji(entry);
}

Future<void> _handleRecentSelection(
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
  ChatExpressionRegistry registry,
  ChatExpressionRecentRecord recent,
) async {
  switch (recent.kind) {
    case ChatExpressionKind.emoji:
      _insertEmoji(recent.itemId, composerController, mentionsController);
      await registry.rememberRecent(recent);
      return;
    case ChatExpressionKind.sticker:
      await _handleStickerTap(
        composerController,
        registry,
        ChatStickerDefinition(
          packId: recent.categoryId.replaceFirst('sticker:', ''),
          stickerId: recent.itemId,
          title: recent.itemId,
          previewKey: recent.previewKey,
          animationKey: recent.animationKey,
          mimeType: 'image/webp',
          width: recent.width,
          height: recent.height,
          loopCount: 0,
          fallbackText: recent.displayText,
        ),
      );
      return;
    case ChatExpressionKind.gif:
      await _handlePanelGifTap(
        composerController,
        registry,
        ChatGifPanelResult(
          url: recent.gifUrl,
          width: recent.width,
          height: recent.height,
          title: recent.itemId,
        ),
      );
      return;
  }
}
```

```dart
Widget _buildExpressionPanel(
  ChatComposerState composerState,
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) {
  return FutureBuilder<ChatExpressionRegistrySnapshot>(
    future: ref.read(chatExpressionRegistryProvider).load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }

      return ChatExpressionPanel(
        snapshot: snapshot.data!,
        activeCategoryId: composerState.activeExpressionCategoryId,
        gifResults: _panelGifResults,
        gifErrorText: _panelGifErrorText,
        onCategorySelected: (categoryId) {
          composerController.selectExpressionCategory(categoryId);
          if (categoryId != 'gif') {
            setState(() {
              _panelGifResults = const <ChatGifPanelResult>[];
              _panelGifErrorText = null;
            });
          }
        },
        onRecentSelected: (recent) => unawaited(
          _handleRecentSelection(
            composerController,
            mentionsController,
            ref.read(chatExpressionRegistryProvider),
            recent,
          ),
        ),
        onEmojiSelected: (entry) => unawaited(
          _handlePanelEmojiTap(
            composerController,
            mentionsController,
            ref.read(chatExpressionRegistryProvider),
            entry,
          ),
        ),
        onStickerSelected: (_, sticker) => unawaited(
          _handleStickerTap(
            composerController,
            ref.read(chatExpressionRegistryProvider),
            sticker,
          ),
        ),
        onGifQueryChanged: (query) => unawaited(
          _handlePanelGifQueryChanged(query, composerController),
        ),
        onGifSelected: (result) => unawaited(
          _handlePanelGifTap(
            composerController,
            ref.read(chatExpressionRegistryProvider),
            result,
          ),
        ),
        onBackspaceTap: () => _deletePreviousComposerCharacter(
          composerController,
          mentionsController,
        ),
      );
    },
  );
}
```

```dart
Future<void> _handlePanelGifQueryChanged(
  String query,
  ChatComposerController composerController,
) async {
  composerController.updateExpressionSearchQuery(query);
  final normalized = query.trim();
  if (normalized.isEmpty) {
    setState(() {
      _panelGifResults = const <ChatGifPanelResult>[];
      _panelGifErrorText = null;
    });
    return;
  }

  try {
    final results = await ref
        .read(chatGifPanelServiceProvider)
        .search(normalized, session: widget.session);
    if (!mounted) {
      return;
    }
    setState(() {
      _panelGifResults = results;
      _panelGifErrorText = null;
    });
  } catch (_) {
    if (!mounted) {
      return;
    }
    setState(() {
      _panelGifResults = const <ChatGifPanelResult>[];
      _panelGifErrorText = 'GIF 加载失败，请重试';
    });
  }
}
```

```dart
Widget _buildPanel(
  ChatComposerState composerState,
  List<ChatFunctionMenu> functionItems,
  WKChannel? channel,
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) {
  if (_robotGifResults.isNotEmpty) {
    return _buildRobotGifPanel(composerController);
  }
  if (composerState.showFlamePanel == true && _isChannelFlameEnabled(channel)) {
    return _buildFlamePanel(channel, composerController);
  }
  if (composerState.showRobotMenuPanel == true && widget.robotMenus.isNotEmpty) {
    return _buildRobotMenuPanel(composerController);
  }
  if (composerState.showFunctionPanel == true) {
    return _buildFunctionPanel(functionItems);
  }
  if (composerState.showFacePanel == true) {
    return _buildExpressionPanel(
      composerState,
      composerController,
      mentionsController,
    );
  }
  return const SizedBox.shrink(key: ValueKey<String>('panel-none'));
}
```

- [ ] **Step 4: Re-run the parity tests and verify the integrated panel now drives sticker and GIF send paths**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`

Expected: PASS with `WKStickerContent` for local sticker taps and `WKGifContent` for GIF results.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: route unified expression panel send paths"
```

### Task 5: Render sticker messages safely with animation, preview, and placeholder fallbacks

**Files:**

- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Add failing message bubble tests for sticker render and fallback behavior**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('sticker bubble renders bundled local asset when animation key exists', (tester) async {
    final message = WKMsg()
      ..fromUID = 'u_me'
      ..channelType = WKChannelType.personal
      ..contentType = WkMessageContentType.sticker
      ..messageContent = WKStickerContent(
        packId: 'android_sample_motion',
        stickerId: 'typing',
        previewKey: 'assets/stickers/sample_pack/typing.webp',
        animationKey: 'assets/stickers/sample_pack/typing.webp',
        fallbackText: '[贴纸]',
      )
      ..status = WKSendMsgResult.sendSuccess;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            model: ChatMessageMapper().map(message, currentUid: 'u_me'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('message-sticker-body')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/stickers/sample_pack/typing.webp',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sticker bubble falls back to placeholder card when assets are missing', (tester) async {
    final message = WKMsg()
      ..fromUID = 'u_other'
      ..channelType = WKChannelType.personal
      ..contentType = WkMessageContentType.sticker
      ..messageContent = WKStickerContent(
        packId: 'missing_pack',
        stickerId: 'missing_sticker',
        previewKey: 'assets/stickers/sample_pack/not-found.webp',
        animationKey: 'assets/stickers/sample_pack/not-found.webp',
        fallbackText: '[贴纸]',
      )
      ..status = WKSendMsgResult.sendSuccess;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            model: ChatMessageMapper().map(message, currentUid: 'u_me'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('message-sticker-placeholder')),
      findsOneWidget,
    );
    expect(find.text('[贴纸]'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the message bubble tests and verify they fail before sticker rendering exists**

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`

Expected: FAIL because `message_bubble.dart` does not branch on `WkMessageContentType.sticker`.

- [ ] **Step 3: Add a dedicated sticker branch in `MessageBubble` with animation -> preview -> placeholder -> text fallback**

```dart
EdgeInsets _bubblePaddingFor(int effectiveContentType) {
  if (effectiveContentType == WkMessageContentType.image ||
      effectiveContentType == WkMessageContentType.gif ||
      effectiveContentType == WkMessageContentType.video ||
      effectiveContentType == WkMessageContentType.sticker) {
    return const EdgeInsets.all(10);
  }
  return const EdgeInsets.fromLTRB(14, 10, 14, 9);
}
```

```dart
Widget _buildContent({
  required BuildContext context,
  required String previewText,
  int? effectiveContentType,
}) {
  final reply = message.messageContent?.reply;
  final resolvedContentType =
      effectiveContentType ?? _resolveEffectiveContentType();
  Widget content = switch (resolvedContentType) {
    WkMessageContentType.text => _buildTextContent(previewText),
    WkMessageContentType.image => _buildImageContent(context),
    WkMessageContentType.gif => _buildGifContent(context),
    WkMessageContentType.sticker => _buildStickerContent(),
    WkMessageContentType.voice =>
      voiceContentBuilder?.call(context, model, isSelf) ?? _buildVoiceContent(),
    WkMessageContentType.video => _buildVideoContent(context),
    WkMessageContentType.location => _buildLocationContent(),
    WkMessageContentType.file => _buildFileContent(),
    WkMessageContentType.card => _buildInteractiveCardContent(),
    MsgContentType.richText => _buildRichTextContent(context),
    _ => _buildTextContent(previewText),
  };
```

```dart
Widget _buildStickerContent() {
  final typed = message.messageContent;
  final payload = model.structuredPayload;
  final animationKey = typed is WKStickerContent
      ? typed.animationKey.trim()
      : _readStructuredString(payload, <String>['animationKey', 'animation']);
  final previewKey = typed is WKStickerContent
      ? typed.previewKey.trim()
      : _readStructuredString(payload, <String>['previewKey', 'preview']);
  final fallbackText = typed is WKStickerContent
      ? (typed.fallbackText.trim().isEmpty ? '[贴纸]' : typed.fallbackText.trim())
      : '[贴纸]';

  return ClipRRect(
    borderRadius: BorderRadius.circular(WKRadius.md),
    child: SizedBox(
      key: const ValueKey<String>('message-sticker-body'),
      width: 160,
      height: 160,
      child: _buildStickerAsset(
        animationKey: animationKey,
        previewKey: previewKey,
        fallbackText: fallbackText,
      ),
    ),
  );
}

Widget _buildStickerAsset({
  required String animationKey,
  required String previewKey,
  required String fallbackText,
}) {
  if (animationKey.isNotEmpty) {
    return Image.asset(
      animationKey,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _buildStickerPreviewOrPlaceholder(
        previewKey: previewKey,
        fallbackText: fallbackText,
      ),
    );
  }
  return _buildStickerPreviewOrPlaceholder(
    previewKey: previewKey,
    fallbackText: fallbackText,
  );
}

Widget _buildStickerPreviewOrPlaceholder({
  required String previewKey,
  required String fallbackText,
}) {
  if (previewKey.isNotEmpty) {
    return Image.asset(
      previewKey,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _buildStickerPlaceholder(fallbackText),
    );
  }
  return _buildStickerPlaceholder(fallbackText);
}

Widget _buildStickerPlaceholder(String fallbackText) {
  return Container(
    key: const ValueKey<String>('message-sticker-placeholder'),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isSelf ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(WKRadius.md),
      border: Border.all(
        color: isSelf ? Colors.white.withValues(alpha: 0.24) : const Color(0xFFE4E9F1),
      ),
    ),
    child: Text(
      fallbackText,
      style: TextStyle(
        color: isSelf ? WKColors.sendText : WKColors.receiveText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
```

- [ ] **Step 4: Re-run the message bubble tests and verify sticker content now renders or degrades safely**

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS with local asset render for bundled stickers and placeholder fallback for missing assets.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: render sticker messages with fallbacks"
```

### Task 6: Run the focused regression sweep for panel parity, send routing, previews, and sticker rendering

**Files:**

- Modify: only the files from Tasks 1 through 5 if a verification failure exposes a regression
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_sticker_content_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_registry_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_expression_panel_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_composer_controller_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_page_android_parity_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Run the focused automated regression suite**

Run: `flutter test test/modules/chat/chat_sticker_content_test.dart test/modules/chat/chat_expression_registry_test.dart test/modules/chat/chat_expression_panel_test.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_content_preview_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS.

- [ ] **Step 2: Run a manual panel parity checklist on desktop**

Run manually:

1. Open any personal chat and tap the emoji toolbar button.
2. Confirm one expression panel opens and stays anchored under the toolbar.
3. Confirm the bottom strip contains recent, emoji categories, the bundled sticker pack, and GIF in one row.
4. Tap an emoji item and confirm it inserts into the input without leaving the panel shell.
5. Tap the bundled sticker pack, send one local sticker, and confirm the outgoing content is a sticker bubble instead of a GIF bubble.
6. Switch to GIF, search for a term, send one GIF, and confirm it still renders as a `WKGifContent` bubble.
7. Reopen the panel and confirm the recent category can show mixed history instead of only emoji history.
8. Tap an emoji recent, a sticker recent, and a GIF recent, and confirm each replays through its original send path instead of collapsing into one generic handler.
9. Temporarily break one sticker asset path in the manifest, hot-reload, and confirm the received bubble degrades to the sticker placeholder instead of crashing or going blank.

- [ ] **Step 3: Re-run the previous Android chat parity suite to guard against layout regressions**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_flame_composer_parity_test.dart test/modules/chat/chat_text_sticker_conversion_test.dart`

Expected: PASS, including the previously aligned two-row composer, flame behavior, and text-to-emoji conversion hook.

- [ ] **Step 4: Commit**

```bash
git add ..\TangSengDaoDao\WuKongIMFlutterSDK-master\lib lib pubspec.yaml assets/stickers test/modules/chat
git commit -m "feat: complete unified expression panel sticker alignment"
```
