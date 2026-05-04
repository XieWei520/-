import 'package:flutter/material.dart';

import '../../service/api/collection_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_status_view.dart';
import 'settings_strings.dart';

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await SettingsApi.instance.getDevices();
      if (!mounted) {
        return;
      }
      setState(() => _devices = devices);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _devices = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.removeDeviceTitle),
          content: Text(strings.removeDeviceMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                strings.remove,
                style: const TextStyle(color: WKColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await SettingsApi.instance.deleteDevice(deviceId);
      await _loadDevices();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.removeFailed(error)),
          backgroundColor: WKColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.signedInDevicesTitle)),
        body: WKLoadingView(message: strings.loading),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.signedInDevicesTitle)),
      body: _devices.isEmpty
          ? WKEmptyView(
              icon: Icons.devices_outlined,
              message: strings.noDevices,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                WKSpace.md,
                WKSpace.md,
                WKSpace.md,
                WKSpace.xl,
              ),
              itemCount: _devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: WKSpace.sm),
              itemBuilder: (context, index) {
                final device = _devices[index];
                final isCurrentDevice = device['is_current'] == true;
                final isIos = device['device_type'] == 'iOS';

                return Container(
                  decoration: BoxDecoration(
                    color: WKColors.surface,
                    borderRadius: BorderRadius.circular(WKRadius.xl),
                    border: Border.all(color: WKColors.outline),
                    boxShadow: WKShadows.soft,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: WKColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(WKRadius.lg),
                      ),
                      child: Icon(
                        isIos
                            ? Icons.phone_iphone_rounded
                            : Icons.phone_android_rounded,
                      ),
                    ),
                    title: Text(
                      device['device_name']?.toString() ?? strings.unknownDevice,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(device['login_time']?.toString() ?? ''),
                        if (isCurrentDevice)
                          Text(
                            strings.currentDevice,
                            style: const TextStyle(
                              color: WKColors.success,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: isCurrentDevice
                        ? null
                        : IconButton(
                            onPressed: () =>
                                _deleteDevice(device['device_id']?.toString() ?? ''),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: WKColors.danger,
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
