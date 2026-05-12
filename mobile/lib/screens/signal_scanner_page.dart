import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SignalScannerPage extends StatefulWidget {
  const SignalScannerPage({super.key});

  @override
  State<SignalScannerPage> createState() => _SignalScannerPageState();
}

class _SignalScannerPageState extends State<SignalScannerPage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    setState(() => isScanning = true);
    
    // Tarama sonuçlarını dinle
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          scanResults = results;
        });
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    
    if (mounted) setState(() => isScanning = false);
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlık Sinyal Tarayıcı'),
        actions: [
          if (isScanning)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tespit Edilen Sinyal Sayısı:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${scanResults.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                final name = result.device.platformName.isEmpty ? "Gizli Cihaz" : result.device.platformName;
                final rssi = result.rssi; // Sinyal Gücü

                return ListTile(
                  leading: Icon(Icons.bluetooth, color: _getRSSIColor(rssi)),
                  title: Text(name),
                  subtitle: Text('ID: ${result.device.remoteId}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$rssi dBm', style: TextStyle(color: _getRSSIColor(rssi), fontWeight: FontWeight.bold)),
                      const Text('Sinyal', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRSSIColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -80) return Colors.orange;
    return Colors.red;
  }
}