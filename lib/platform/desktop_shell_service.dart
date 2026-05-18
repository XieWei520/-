import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'desktop_shell_contract.dart';
import 'desktop_shell_service_stub.dart'
    if (dart.library.js_interop) 'desktop_shell_service_web.dart'
    if (dart.library.io) 'desktop_shell_service_io.dart';

export 'desktop_shell_contract.dart';

DesktopShellService createDesktopShellService() =>
    createPlatformDesktopShellService();

final desktopShellServiceProvider = Provider<DesktopShellService>(
  (ref) => createDesktopShellService(),
);
