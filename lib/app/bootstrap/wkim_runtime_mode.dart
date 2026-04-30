import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../wk_foundation/runtime/app_environment.dart';

void configureWkImRuntimeMode(AppEnvironment environment) {
  WKIM.shared.runMode = environment.isWeb ? Model.web : Model.app;
}
