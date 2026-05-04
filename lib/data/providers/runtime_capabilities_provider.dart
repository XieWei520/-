import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api/common_api.dart';

final runtimeCapabilitiesProvider =
    FutureProvider<AppRuntimeCapabilities>((ref) async {
      return CommonApi.instance.getRuntimeCapabilities();
    });
