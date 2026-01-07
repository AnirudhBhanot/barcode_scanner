import 'package:barcode_scanner/app_launcher.dart';
import 'package:barcode_scanner/homepage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

/* ===============================
   APP ROOT
================================ */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Setup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5D1E), // Dark Green
        ),
        useMaterial3: true,
      ),
      home: const AppLauncher(),
    );
  }
}

/* ===============================
   SCANNER NAME PAGE
================================ */
class ScannerNamePage extends StatefulWidget {
  const ScannerNamePage({super.key});

  @override
  State<ScannerNamePage> createState() => _ScannerNamePageState();
}

class _ScannerNamePageState extends State<ScannerNamePage> {
  final TextEditingController _scannerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  Future<void> _saveAndProceed() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSaving = true);

  final scannerName = _scannerController.text.trim();
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('scannerName', scannerName);

  setState(() => _isSaving = false);

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => HomePage(scannerName: scannerName,)),
  );
}


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth < 600
        ? screenWidth * 0.9
        : 420.toDouble();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B5D1E), // Dark Green
              Color(0xFF1E7F35), // Light Green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 20,
            color: Colors.white,
            shadowColor: Colors.black.withOpacity(0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ LOGO
                    Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0B5D1E), // Dark Green border
                          width: 4,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          "images/kuantam_logo.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ✅ TITLE
                    const Text(
                      "Scanner Setup",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B5D1E),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Enter Scanner Name to Continue",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),

                    const SizedBox(height: 28),

                    // ✅ SCANNER NAME FIELD
                    TextFormField(
                      controller: _scannerController,
                      decoration: InputDecoration(
                        labelText: "Scanner Name",
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner,
                          color: Color(0xFF0B5D1E),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF0B5D1E),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Please enter scanner name" : null,
                    ),

                    const SizedBox(height: 26),

                    // ✅ SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndProceed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF0B5D1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 6,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                "Save & Continue",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
