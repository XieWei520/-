import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/conversation/web_conversation_workspace.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  test('desktop conversation workspace policy includes native Windows', () {
    expect(
      shouldUseDesktopConversationWorkspace(
        isWeb: false,
        platform: TargetPlatform.windows,
        viewportWidth: 1200,
      ),
      isTrue,
    );
    expect(
      shouldUseDesktopConversationWorkspace(
        isWeb: false,
        platform: TargetPlatform.android,
        viewportWidth: 1200,
      ),
      isFalse,
    );
    expect(
      shouldUseDesktopConversationWorkspace(
        isWeb: true,
        platform: TargetPlatform.android,
        viewportWidth: 1200,
      ),
      isTrue,
    );
  });

  test('desktop workspace decision uses Web viewport and preserves native', () {
    expect(
      shouldUseWebConversationWorkspace(isWeb: true, viewportWidth: 1023),
      isFalse,
    );
    expect(
      shouldUseWebConversationWorkspace(isWeb: true, viewportWidth: 1024),
      isTrue,
    );
    expect(
      shouldUseWebConversationWorkspace(isWeb: false, viewportWidth: 1440),
      isFalse,
    );
  });

  testWidgets('desktop workspace shows list and empty chat pane side by side', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 720,
          child: WebConversationWorkspaceScaffold(
            listPane: const Text('list pane'),
            chatPane: const Text('select a conversation'),
            showRightContext: false,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('web-conversation-workspace')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('web-conversation-list-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('web-conversation-chat-pane')),
      findsOneWidget,
    );
    expect(find.text('list pane'), findsOneWidget);
    expect(find.text('select a conversation'), findsOneWidget);
  });

  testWidgets('wide workspace can display the right context pane', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1280,
          height: 720,
          child: WebConversationWorkspaceScaffold(
            listPane: Text('list'),
            chatPane: Text('chat'),
            rightContextPane: Text('context'),
            showRightContext: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('web-conversation-right-pane')),
      findsOneWidget,
    );
    expect(find.text('context'), findsOneWidget);
  });

  testWidgets(
    'workspace adapts panes instead of overflowing when right context is requested on a tight width',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 760,
            height: 640,
            child: WebConversationWorkspaceScaffold(
              listPane: Text('list'),
              chatPane: Text('chat'),
              rightContextPane: Text('context'),
              showRightContext: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('web-conversation-right-pane')),
        findsNothing,
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('web-conversation-list-pane')),
            )
            .width,
        lessThanOrEqualTo(WKWebSizes.conversationListWidth),
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('web-conversation-chat-pane')),
            )
            .width,
        greaterThan(0),
      );
    },
  );

  testWidgets('conversation workbench shows approved title and sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: ConversationWorkbenchPanel(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('conversation-workbench-panel')),
      findsOneWidget,
    );
    expect(find.text('会话工作台'), findsOneWidget);
    expect(find.text('成员'), findsOneWidget);
    expect(find.text('置顶 / 公告'), findsOneWidget);
    expect(find.text('文件与图片'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('会话信息'), findsNothing);
  });

  testWidgets(
    'conversation workbench uses selected conversation display name',
    (tester) async {
      const selection = WebConversationWorkspaceSelection(
        session: ChatSession(channelId: 'group_1', channelType: 2),
        channelName: 'test1、平权客服、LD',
        channelCategory: 'group',
        initialVipLevel: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 320,
            height: 640,
            child: ConversationWorkbenchPanel(selection: selection),
          ),
        ),
      );

      expect(find.text('test1、平权客服、LD'), findsOneWidget);
      expect(find.text('group'), findsOneWidget);
    },
  );

  testWidgets('production workbench seam preserves selection context', (
    tester,
  ) async {
    const selection = WebConversationWorkspaceSelection(
      session: ChatSession(channelId: 'group_1', channelType: 2),
      channelName: 'test1、平权客服、LD',
      channelCategory: 'group',
      initialVipLevel: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: buildConversationWorkbenchPaneForSelection(selection),
        ),
      ),
    );

    expect(find.text('会话工作台'), findsOneWidget);
    expect(find.text('test1、平权客服、LD'), findsOneWidget);
    expect(find.text('group'), findsOneWidget);
  });

  testWidgets('conversation workbench avatar preserves emoji grapheme', (
    tester,
  ) async {
    const selection = WebConversationWorkspaceSelection(
      session: ChatSession(channelId: 'emoji_1', channelType: 2),
      channelName: '😀Alice',
      channelCategory: 'group',
      initialVipLevel: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: ConversationWorkbenchPanel(selection: selection),
        ),
      ),
    );

    expect(find.text('😀Alice'), findsOneWidget);
    expect(find.text('😀'), findsOneWidget);
  });

  testWidgets('conversation workbench trims blank category fallback', (
    tester,
  ) async {
    const selection = WebConversationWorkspaceSelection(
      session: ChatSession(channelId: 'group_1', channelType: 2),
      channelName: 'Group One',
      channelCategory: '   ',
      initialVipLevel: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: ConversationWorkbenchPanel(selection: selection),
        ),
      ),
    );

    expect(find.text('暂无会话状态'), findsOneWidget);
  });

  testWidgets('wide workspace can display the approved workbench panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1280,
          height: 720,
          child: WebConversationWorkspaceScaffold(
            listPane: Text('list'),
            chatPane: Text('chat'),
            rightContextPane: ConversationWorkbenchPanel(),
            showRightContext: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('web-conversation-right-pane')),
      findsOneWidget,
    );
    expect(find.text('会话工作台'), findsOneWidget);
    expect(find.text('会话信息'), findsNothing);
  });

  testWidgets(
    'desktop workspace still shows workbench at Windows scaled logical width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(944, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 944,
            height: 640,
            child: WebConversationWorkspaceScaffold(
              listPane: Text('list'),
              chatPane: Text('chat'),
              rightContextPane: ConversationWorkbenchPanel(),
              showRightContext: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('web-conversation-right-pane')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-workbench-toggle')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'workspace toggle can collapse and expand the conversation workbench',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var expanded = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 1280,
                height: 720,
                child: WebConversationWorkspaceScaffold(
                  listPane: const Text('list'),
                  chatPane: const Text('chat'),
                  rightContextPane: const ConversationWorkbenchPanel(),
                  showRightContext: true,
                  workbenchExpanded: expanded,
                  onWorkbenchExpandedChanged: (value) {
                    setState(() => expanded = value);
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('web-conversation-right-pane')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('conversation-workbench-toggle')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('web-conversation-right-pane')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-workbench-toggle')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('conversation-workbench-toggle')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('web-conversation-right-pane')),
        findsOneWidget,
      );
    },
  );
}
