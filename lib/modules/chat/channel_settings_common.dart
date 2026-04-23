import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/wkim.dart';

class ChannelAutoDeleteOption {
  const ChannelAutoDeleteOption({
    required this.seconds,
    required this.zhLabel,
    required this.enLabel,
  });

  final int seconds;
  final String zhLabel;
  final String enLabel;

  String label(bool english) => english ? enLabel : zhLabel;
}

const List<ChannelAutoDeleteOption>
channelAutoDeleteOptions = <ChannelAutoDeleteOption>[
  ChannelAutoDeleteOption(seconds: 0, zhLabel: '关闭', enLabel: 'Off'),
  ChannelAutoDeleteOption(seconds: 86400, zhLabel: '1天', enLabel: '1 day'),
  ChannelAutoDeleteOption(seconds: 604800, zhLabel: '7天', enLabel: '7 days'),
  ChannelAutoDeleteOption(seconds: 2592000, zhLabel: '30天', enLabel: '30 days'),
];

bool isEnglishLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'en';

String formatChannelAutoDeleteLabel(int seconds, {required bool english}) {
  for (final option in channelAutoDeleteOptions) {
    if (option.seconds == seconds) {
      return option.label(english);
    }
  }
  if (seconds <= 0) {
    return english ? 'Off' : '关闭';
  }
  if (seconds % 86400 == 0) {
    final days = seconds ~/ 86400;
    return english ? '$days day${days == 1 ? '' : 's'}' : '${days}天';
  }
  if (seconds % 3600 == 0) {
    final hours = seconds ~/ 3600;
    return english ? '$hours hour${hours == 1 ? '' : 's'}' : '${hours}小时';
  }
  return english ? '$seconds sec' : '${seconds}秒';
}

Future<int?> showChannelAutoDeletePicker({
  required BuildContext context,
  required int currentSeconds,
  String? title,
}) {
  final english = isEnglishLocale(context);
  final resolvedTitle = title ?? (english ? 'Auto Delete Messages' : '消息自动删除');

  return showModalBottomSheet<int>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(resolvedTitle)),
            for (final option in channelAutoDeleteOptions)
              ListTile(
                key: ValueKey<String>(
                  'channel_auto_delete_option_${option.seconds}',
                ),
                title: Text(option.label(english)),
                trailing: option.seconds == currentSeconds
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.seconds),
              ),
          ],
        ),
      );
    },
  );
}

Map<String, dynamic> mutableChannelExtraMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

int readChannelExtraInt(dynamic raw, String key) {
  final map = mutableChannelExtraMap(raw);
  final value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Future<void> updateChannelExtraCache({
  required String channelId,
  required int channelType,
  String? channelName,
  int? chatPwdOn,
  int? msgAutoDelete,
}) async {
  final existing = await WKIM.shared.channelManager.getChannel(
    channelId,
    channelType,
  );
  final channel = existing ?? WKChannel(channelId, channelType);
  final normalizedName = channelName?.trim() ?? '';
  if (normalizedName.isNotEmpty) {
    channel.channelName = normalizedName;
  }

  final remoteExtra = mutableChannelExtraMap(channel.remoteExtraMap);
  final localExtra = mutableChannelExtraMap(channel.localExtra);
  if (chatPwdOn != null) {
    remoteExtra['chat_pwd_on'] = chatPwdOn;
    localExtra['chat_pwd_on'] = chatPwdOn;
  }
  if (msgAutoDelete != null) {
    remoteExtra['msg_auto_delete'] = msgAutoDelete;
    localExtra['msg_auto_delete'] = msgAutoDelete;
  }

  channel.remoteExtraMap = remoteExtra;
  channel.localExtra = localExtra;
  WKIM.shared.channelManager.addOrUpdateChannel(channel);
}
