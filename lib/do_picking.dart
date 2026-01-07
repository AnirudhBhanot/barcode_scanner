import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class DoPickingPage extends StatefulWidget {
  final String scannerName;
  const DoPickingPage({super.key, required this.scannerName});

  @override
  State<DoPickingPage> createState() => _DoPickingPageState();
}

class _DoPickingPageState extends State<DoPickingPage> {
  int scanCount = 0;
  final TextEditingController scanCountController = TextEditingController(
    text: "0",
  );

  final Map<String, TextEditingController> fieldControllers = {
    "Shno.": TextEditingController(),
    "Batch": TextEditingController(),
    "DPR Date": TextEditingController(),
    "Desc": TextEditingController(),
    "Loc.": TextEditingController(),
    "RmWt.": TextEditingController(),
    "No. Reams": TextEditingController(),
    "Qty.": TextEditingController(),
    "Segment": TextEditingController(),
    "NetWt.": TextEditingController(),
    "GrossWt.": TextEditingController(),
    "Total": TextEditingController(),
    "Total Weight": TextEditingController(),
  };

  // 🔥 Scanner-critical
  final FocusNode shnoFocus = FocusNode();
  final FocusNode batchFocus = FocusNode();

  bool isLoading = false;
  String lvMessage = "";

  @override
  void initState() {
    super.initState();
    _setCurrentDprDate();

    fieldControllers["Batch"]?.addListener(_checkAutoScan);
    fieldControllers["Shno."]?.addListener(_checkAutoScan);
  }

  void _setCurrentDprDate() {
    fieldControllers["DPR Date"]?.text = DateFormat(
      'dd-MM-yyyy',
    ).format(DateTime.now());
  }

  void _clearAfterScan() {
    fieldControllers["Batch"]?.clear();

    // 🔥 scanner instantly ready again
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) batchFocus.requestFocus();
    });
  }

  void _checkAutoScan() {
    final batch = fieldControllers["Batch"]?.text.trim() ?? "";
    final shno = fieldControllers["Shno."]?.text.trim() ?? "";

    if (batch.isNotEmpty && shno.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted &&
            fieldControllers["Batch"]?.text.trim() == batch &&
            fieldControllers["Shno."]?.text.trim() == shno) {
          scanData();
        }
      });
    }
  }

  Future<void> scanData() async {
    final batchNo = fieldControllers["Batch"]?.text.trim() ?? "";
    final shipmentNo = fieldControllers["Shno."]?.text.trim() ?? "";
    final scanName = widget.scannerName;

    if (batchNo.isEmpty || shipmentNo.isEmpty || isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/GetDoPickingData"
          "?batchNo=$batchNo"
          "&scanName=$scanName"
          "&shipmentNo=$shipmentNo",
        ),
      );

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);

        // ✅ READ LV_MESS FROM SAP
        final messageElement =
            xmlDoc.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Scanned successfully";

        // ✅ READ ITEM DATA
        final items = xmlDoc.findAllElements('item').toList();

        if (items.isNotEmpty) {
          final item = items.last;

          setState(() {
            _setCurrentDprDate();

            fieldControllers["Loc."]?.text =
                item.getElement('LOCATION')?.innerText ?? '';
            fieldControllers["RmWt."]?.text =
                item.getElement('RM_WT')?.innerText ?? '';
            fieldControllers["No. Reams"]?.text =
                item.getElement('NO_REM')?.innerText ?? '';
            fieldControllers["Desc"]?.text =
                item.getElement("BELOW_LOC")?.innerText ?? '';
            fieldControllers["Qty."]?.text =
                item.getElement('QUANTITY')?.innerText ?? '';
            fieldControllers["Segment"]?.text =
                item.getElement('SEGMENT')?.innerText ?? '';
            fieldControllers["NetWt."]?.text =
                item.getElement('NETWT')?.innerText ?? '';
            fieldControllers["GrossWt."]?.text =
                item.getElement('GROSS_WT')?.innerText ?? '';
            fieldControllers["Total"]?.text =
                item.getElement('TOTAL')?.innerText ?? '';
            fieldControllers["Total Weight"]?.text =
                item.getElement('TOTAL_WEIGHT')?.innerText ?? '';

            // ✅ AUTO INCREMENT SCAN COUNT
            scanCount++;
            scanCountController.text = scanCount.toString();
          });

          // ✅ SUCCESS MESSAGE
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ $message | Scans: $scanCount"),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 1),
            ),
          );

          // 🔥 CLEAR BATCH & READY FOR NEXT SCAN
          _clearAfterScan();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Scan failed: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> postData() async {
    final shipmentNo = fieldControllers["Shno."]?.text.trim() ?? "";
    final scanName = widget.scannerName;

    if (shipmentNo.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/PostDoPickingData"
          "?shipmentNo=$shipmentNo"
          "&scanName=$scanName",
        ),
      );

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);

        // ✅ READ LV_MESS FROM SAP
        final messageElement =
            xmlDoc.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Posted successfully";

        // ✅ SUCCESS MESSAGE
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $message"),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );

        // 🔥 CLEAR EVERYTHING AFTER POST
        clearFields();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Post failed: ${response.statusCode}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error posting data: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void clearFields() {
    for (var key in fieldControllers.keys) {
      if (key != "DPR Date") fieldControllers[key]?.clear();
    }
    _setCurrentDprDate();
    batchFocus.requestFocus(); // 🔥 scanner stays ready
  }

  @override
  void dispose() {
    shnoFocus.dispose();
    batchFocus.dispose();
    for (var c in fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final gridFields = [
      "DPR Date",
      "RmWt.",
      "No. Reams",
      "Qty.",
      "Segment",
      "NetWt.",
      "GrossWt.",
      "Total",
      "Total Weight",
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B5D1E),
      appBar: AppBar(
        title: const Text(
          "DO Picking",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        top: true, // ✅ FIX APPBAR OVERLAP
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B5D1E), Color(0xFF1E7F35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Card(
              elevation: 25,
              color: Colors.white.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Container(
                width: isMobile ? 460 : 600,
                height: 800,
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// Shipment
                      TextFormField(
                        controller: fieldControllers["Shno."],
                        focusNode: shnoFocus,
                        decoration: _decoration("Shno."),
                        style: _style(),
                      ),
                      const SizedBox(height: 14),

                      /// 🔥 BIG FULL-WIDTH BATCH FIELD
                      TextFormField(
                        controller: fieldControllers["Batch"],
                        focusNode: batchFocus,
                        autofocus: true,
                        style: _style(fontSize: 20),
                        decoration: _decoration("Batch", scan: true),
                        onEditingComplete: scanData,
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: scanCountController,
                        enabled: false,
                        style: _style(fontSize: 18),
                        decoration: _decoration("No. of Scans"),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: fieldControllers["Desc"],
                        enabled: false,
                        style: _style(fontSize: 18),
                        decoration: _decoration("Description"),
                      ),

                      const SizedBox(height: 12),

                      /// Remaining fields
                      SizedBox(
                        height: 420,
                        child: GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3.5,
                          children: gridFields.map((label) {
                            return TextFormField(
                              controller: fieldControllers[label],
                              enabled: false,
                              style: _style(),
                              decoration: _decoration(label),
                            );
                          }).toList(),
                        ),
                      ),

                      SizedBox(height: 50),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildButton(
                            "Post",
                            Colors.deepPurpleAccent,
                            postData,
                          ),
                          _buildButton("Clear", Colors.blueAccent, clearFields),
                          _buildButton(
                            "Back",
                            Colors.orangeAccent,
                            () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {bool scan = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(scan ? 0.18 : 0.08),
      contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  TextStyle _style({double fontSize = 15}) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
