import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/call.dart';
import '../../data/models/chat_session.dart';
import '../../wukong_base/views/mention_suggestion.dart';
import '../video_call/group_call_member_picker_page.dart';
import '../video_call/video_call_page.dart';
import 'chat_action_dispatcher.dart';
import 'chat_call_entry_service.dart';
import 'chat_gif_panel_service.dart';
import 'chat_media_action_service.dart';
import 'chat_message_action_controller.dart';
import 'chat_message_favorite_registry.dart';
import 'chat_mentions_controller.dart';
import 'chat_search_mode_controller.dart';
import 'chat_scene_controller.dart';
import 'chat_scene_gateway.dart';
import 'chat_scene_models.dart';
import 'chat_selection_controller.dart';
import 'chat_voice_action_service.dart';
import 'chat_voice_playback_controller.dart';
import 'expression/chat_expression_registry.dart';

final chatSceneControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSceneController, ChatSceneState, ChatSession>((ref, _) {
      return ChatSceneController();
    });

final chatSceneGatewayProvider = Provider.autoDispose
    .family<ChatSceneGateway, ChatSession>((ref, _) {
      return ApiChatSceneGateway();
    });

final chatMediaActionServiceProvider =
    Provider.autoDispose<ChatMediaActionService>((ref) {
      return PlatformChatMediaActionService();
    });

final chatActionDispatcherProvider = Provider.autoDispose<ChatActionDispatcher>(
  (ref) {
    final media = ref.watch(chatMediaActionServiceProvider);
    return ChatActionDispatcher(
      pickImage: (action) async {
        final viewContext = action.context;
        if (viewContext == null) {
          return null;
        }
        return media.pickImage(viewContext);
      },
      pickFile: (action) async {
        final viewContext = action.context;
        if (viewContext == null) {
          return null;
        }
        return media.pickFile(viewContext);
      },
      pickLocation: (action) async {
        final viewContext = action.context;
        if (viewContext == null) {
          return null;
        }
        return media.pickLocation(viewContext);
      },
      pickCard: (action) async {
        final viewContext = action.context;
        if (viewContext == null) {
          return null;
        }
        return media.pickCard(viewContext);
      },
      pickRichText: (action) async {
        final viewContext = action.context;
        if (viewContext == null) {
          return null;
        }
        return media.pickRichText(viewContext);
      },
    );
  },
);

final chatVoiceActionServiceProvider =
    Provider.autoDispose<ChatVoiceActionService>((ref) {
      final service = PlatformChatVoiceActionService();
      ref.onDispose(service.dispose);
      return service;
    });

final chatVoicePlaybackControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ChatVoicePlaybackController, ChatSession>((ref, _) {
      return ChatVoicePlaybackController();
    });

final chatExpressionRegistryProvider =
    Provider.autoDispose<ChatExpressionRegistry>((ref) {
      return ChatExpressionRegistry();
    });

final chatGifPanelServiceProvider = Provider.autoDispose<ChatGifPanelService>((
  ref,
) {
  return ChatGifPanelService();
});

final chatCallEntryServiceProvider = Provider.autoDispose<ChatCallEntryService>(
  (ref) {
    return PlatformChatCallEntryService();
  },
);

typedef ChatCallPageBuilder =
    Widget Function({
      required String channelId,
      String? channelName,
      required CallType callType,
    });

final chatCallPageBuilderProvider = Provider.autoDispose<ChatCallPageBuilder>((
  ref,
) {
  return ({
    required String channelId,
    String? channelName,
    required CallType callType,
  }) {
    return VideoCallPage(
      channelId: channelId,
      channelName: channelName,
      callType: callType,
    );
  };
});

typedef ChatGroupCallPageBuilder =
    Widget Function({
      required String channelId,
      required int channelType,
      String? channelName,
    });

final chatGroupCallPageBuilderProvider =
    Provider.autoDispose<ChatGroupCallPageBuilder>((ref) {
      return ({
        required String channelId,
        required int channelType,
        String? channelName,
      }) {
        return GroupCallMemberPickerPage(
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
        );
      };
    });

final chatMessageFavoriteRegistryProvider =
    Provider.autoDispose<ChatMessageFavoriteRegistry>((ref) {
      return SharedPrefsChatMessageFavoriteRegistry();
    });

final chatMessageActionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMessageActionController, ChatMessageActionState, ChatSession>((
      ref,
      session,
    ) {
      return ChatMessageActionController(
        gateway: ref.watch(chatSceneGatewayProvider(session)),
        favoriteRegistry: ref.watch(chatMessageFavoriteRegistryProvider),
      );
    });

final chatSelectionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSelectionController, ChatSelectionState, ChatSession>((ref, _) {
      return ChatSelectionController();
    });

final chatSearchModeControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSearchModeController, ChatSearchModeState, ChatSession>((
      ref,
      _,
    ) {
      return ChatSearchModeController();
    });

final chatMentionsControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMentionsController, ChatMentionsState, ChatSession>((ref, _) {
      return ChatMentionsController(
        loadSuggestions: () async => <MentionSuggestion>[],
      );
    });
