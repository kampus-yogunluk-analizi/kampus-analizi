import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'campus_map_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {

  bool loading = false;

  Future<void> requestPermissions() async {

    setState(() {
      loading = true;
    });

    await Permission.location.request();

    await Permission.bluetooth.request();

    await Permission.bluetoothScan.request();

    await Permission.bluetoothConnect.request();

    if (!mounted) return;

    Navigator.pushReplacement(

      context,

      MaterialPageRoute(
        builder: (_) => const CampusMapScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.location_on,
                size: 90,
                color: Color(0xFF146C94),
              ),

              const SizedBox(height: 24),

              const Text(
                'Kampüs Yoğunluk Sistemi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Yoğunluk analizini gösterebilmek için konum ve Bluetooth izinleri gereklidir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(

                width: double.infinity,
                height: 56,

                child: ElevatedButton(

                  onPressed: loading
                      ? null
                      : requestPermissions,

                  child: loading

                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )

                      : const Text(
                          'İzin Ver ve Devam Et',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}