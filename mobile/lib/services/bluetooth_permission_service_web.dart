import 'dart:js_interop';

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
  final bluetooth = browserBluetooth;

  if (bluetooth == null) {
    return const BluetoothPermissionResult(
      supported: false,
      granted: false,
      message: 'Bu tarayıcı Web Bluetooth desteklemiyor. Chrome ile deneyin.',
    );
  }

  try {
    final device = await bluetooth
        .requestDevice(BluetoothRequestOptions(acceptAllDevices: true))
        .toDart;

    final bluetoothDevice = BluetoothDevice(device as JSObject);

    return BluetoothPermissionResult(
      supported: true,
      granted: true,
      message: bluetoothDevice.name == null || bluetoothDevice.name!.isEmpty
          ? 'Bluetooth izni verildi.'
          : 'Bluetooth izni verildi: ${bluetoothDevice.name}',
    );
  } catch (error) {
    return const BluetoothPermissionResult(
      supported: true,
      granted: false,
      message: 'Bluetooth izni verilmedi veya cihaz seçilmedi.',
    );
  }
}

@JS('navigator.bluetooth')
external BrowserBluetooth? get browserBluetooth;

extension type BrowserBluetooth(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestDevice(BluetoothRequestOptions options);
}

extension type BluetoothRequestOptions._(JSObject _) implements JSObject {
  external factory BluetoothRequestOptions({bool acceptAllDevices});
}

extension type BluetoothDevice(JSObject _) implements JSObject {
  external String? get name;
}
