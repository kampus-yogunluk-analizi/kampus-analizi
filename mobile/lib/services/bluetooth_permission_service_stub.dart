class BluetoothPermissionResult {
  const BluetoothPermissionResult({
    required this.supported,
    required this.granted,
    required this.message,
  });

  final bool supported;
  final bool granted;
  final String message;
}

Future<BluetoothPermissionResult> requestWebBluetoothPermission() async {
  return const BluetoothPermissionResult(
    supported: false,
    granted: false,
    message:
        'Web Bluetooth sadece Chrome gibi destekleyen tarayıcılarda çalışır.',
  );
}
