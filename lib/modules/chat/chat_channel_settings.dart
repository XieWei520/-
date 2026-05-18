import 'package:wukongimfluttersdk/entity/channel.dart';

const List<int> chatFlameSecondOptions = <int>[0, 10, 20, 30, 60, 120, 180];

const String chatFlameExitDescription =
    '\u9000\u51fa\u804a\u5929\u7a97\u53e3\u540e\uff0c\u5df2\u8bfb\u6d88\u606f\u81ea\u52a8\u9500\u6bc1';

int? readChannelExtraInt(dynamic map, List<String> keys) {
  if (map is! Map) {
    return null;
  }
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

Map<String, dynamic> mutableChannelExtraMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return <String, dynamic>{...raw};
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

bool isChannelFlameEnabled(WKChannel? channel) {
  return (readChannelExtraInt(channel?.remoteExtraMap, const ['flame']) ??
          readChannelExtraInt(channel?.localExtra, const ['flame']) ??
          0) ==
      1;
}

int channelFlameSecond(WKChannel? channel) {
  return readChannelExtraInt(channel?.remoteExtraMap, const [
        'flame_second',
        'flameSecond',
      ]) ??
      readChannelExtraInt(channel?.localExtra, const [
        'flame_second',
        'flameSecond',
      ]) ??
      0;
}

void applyChannelFlameSettings(
  WKChannel channel, {
  required int flame,
  required int flameSecond,
}) {
  final remoteExtra = mutableChannelExtraMap(channel.remoteExtraMap);
  remoteExtra['flame'] = flame;
  remoteExtra['flame_second'] = flameSecond;
  channel.remoteExtraMap = remoteExtra;

  final localExtra = mutableChannelExtraMap(channel.localExtra);
  localExtra['flame'] = flame;
  localExtra['flame_second'] = flameSecond;
  channel.localExtra = localExtra;
}

double sliderValueForFlameSecond(int flameSecond) {
  final index = chatFlameSecondOptions.indexOf(flameSecond);
  return (index < 0 ? 0 : index).toDouble();
}

int flameSecondForSliderValue(double value) {
  final index = value.round().clamp(0, chatFlameSecondOptions.length - 1);
  return chatFlameSecondOptions[index];
}

String flameSecondLabel(int flameSecond) {
  switch (flameSecond) {
    case 0:
      return '\u9000\u51fa\u540e';
    case 10:
      return '10\u79d2';
    case 20:
      return '20\u79d2';
    case 30:
      return '30\u79d2';
    case 60:
      return '1\u5206\u949f';
    case 120:
      return '2\u5206\u949f';
    case 180:
      return '3\u5206\u949f';
    default:
      return '$flameSecond\u79d2';
  }
}

String flameDescription(int flameSecond) {
  if (flameSecond == 0) {
    return chatFlameExitDescription;
  }
  return '\u6d88\u606f\u9605\u8bfb\u540e${flameSecondLabel(flameSecond)}\u81ea\u52a8\u9500\u6bc1';
}
