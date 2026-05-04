import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/slot_registry.dart';

final slotRegistryProvider = Provider<SlotRegistry>((ref) {
  return SlotRegistry();
});
