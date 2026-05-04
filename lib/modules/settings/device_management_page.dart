import 'package:flutter/material.dart';

import 'device_list_page.dart';

@Deprecated(
  'Use DeviceListPage from lib/modules/settings/device_list_page.dart.',
)
class DeviceManagementPage extends StatelessWidget {
  const DeviceManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeviceListPage();
  }
}
