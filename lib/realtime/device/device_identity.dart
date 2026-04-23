class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.deviceInstallId,
    required this.deviceSessionId,
    required this.bindVersion,
    required this.userId,
    required this.deviceName,
    required this.deviceModel,
  });

  final String deviceId;
  final String deviceInstallId;
  final String deviceSessionId;
  final int bindVersion;
  final String userId;
  final String deviceName;
  final String deviceModel;
}
