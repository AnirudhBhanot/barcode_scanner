import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';
import 'main.dart'; // for ScannerNamePage

class AppLauncher extends StatelessWidget {
  const AppLauncher({super.key});

  Future<Widget> _getStartPage() async {
    final prefs = await SharedPreferences.getInstance();
    final scannerName = prefs.getString('scannerName');

    if (scannerName != null && scannerName.isNotEmpty) {
      return const HomePage();
    }
    return const ScannerNamePage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
