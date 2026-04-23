// WuKong Base module exports
//
// This file exports all public interfaces from wukong_base module.

library;

// Base MVP architecture
export 'base/base_contract.dart';
export 'base/base_model.dart';
export 'base/base_presenter.dart';
export 'base/base_view.dart';

// Endpoint architecture
export 'endpoint/endpoint_manager.dart';
export 'endpoint/endpoint_handler.dart';
export 'endpoint/endpoint_category.dart';
export 'endpoint/endpoint_sid.dart';
export 'endpoint/entity/menu.dart';

// Network layer
export 'net/api_client.dart';
export 'net/ws_manager.dart';

// Database layer
export 'db/db_helper.dart';
export 'db/database_migration.dart';

// Entities
export 'entity/user_info.dart';
export 'entity/friend.dart';
export 'entity/group_info.dart';
export 'entity/channel.dart';
export 'entity/message.dart' hide MsgContentType, WKMessageReaction;
export 'entity/conversation.dart';
export 'entity/message_extra.dart';
export 'entity/message_reaction.dart';

// Utilities
export 'utils/platform_utils.dart';
export 'utils/wk_time_utils.dart';
export 'utils/wk_file_utils.dart';
export 'utils/wk_image_utils.dart';
export 'utils/wk_image_cache.dart';
export 'utils/wk_string_utils.dart';
export 'utils/wk_crypto_utils.dart';
export 'utils/wk_play_sound.dart';
export 'utils/permission_utils.dart';
export 'utils/pinyin_utils.dart';
export 'utils/activity_manager.dart';
export 'utils/log_utils.dart';
export 'utils/audio_record_manager.dart';
export 'utils/download_manager.dart';

// Views / Widgets
export 'views/swipe_back_wrapper.dart';
export 'views/circle_progress.dart';
export 'views/waveform_view.dart';
export 'views/blur_view.dart';
export 'views/custom_bottom_sheet.dart';
export 'views/wk_chat_input_bar.dart';
export 'views/wk_chat_toolbar.dart';
export 'views/wk_emoji_picker.dart';
export 'views/wk_user_avatar.dart';
export 'views/typing_indicator.dart';
export 'views/image_viewer.dart';
export 'views/mention_suggestion.dart';
export 'views/view_exports.dart';

// Message components
export 'msg/msg_content_type.dart' show MsgContentType;
export 'msg/wk_message_content_parser.dart';
export 'msg/message_bubble.dart';
export 'msg/wk_voice_bubble.dart' show WKVoiceBubble;
export 'msg/widget/wk_video_bubble.dart';
export 'msg/widget/wk_file_bubble.dart';
export 'msg/widget/wk_location_bubble.dart';
export 'msg/widget/wk_card_bubble.dart';
export 'msg/widget/wk_recall_bubble.dart';
export 'msg/widget/wk_tip_bubble.dart';
export 'msg/widget/wk_typing_bubble.dart';
export 'msg/wk_message_reactions.dart' hide WKMessageReactions;
export 'msg/widget/wk_multi_forward_bubble.dart';
export 'msg/widget/msg_bubble_exports.dart' hide WKMessageBubble, WKVoiceBubble;
export 'msg/msg_manager_exports.dart';

// Emoji / Stickers
export 'emoji/emoji_utils.dart';
export 'emoji/sticker_manager.dart';
export 'emoji/emoji_exports.dart';

// Providers
export 'providers/message_list_notifier.dart';
export 'providers/conversation_list_notifier.dart';
export 'providers/friend_list_notifier.dart';
export 'providers/group_list_notifier.dart';
