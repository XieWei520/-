import 'package:flutter/foundation.dart';

import '../../modules/settings/settings_strings.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class PersonalCenterSlotContext {
  const PersonalCenterSlotContext({
    required this.hasNewVersion,
    this.strings = zhHansSettingsStrings,
  });

  final bool hasNewVersion;
  final SettingsStrings strings;
}

const personalCenterSlot = SlotDescriptor<
    PersonalCenterSlotContext,
    PersonalInfoMenu>('personal.center');
