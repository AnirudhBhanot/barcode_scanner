import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';
import 'package:intl/intl.dart';

class StockInPage extends StatefulWidget {
  final String scannerName;
  const StockInPage({super.key, required this.scannerName});

  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  int scanCount = 0;
  final TextEditingController scanCountController = TextEditingController(
    text: "0",
  );

  final TextEditingController batchController = TextEditingController();
  final TextEditingController dprDateController = TextEditingController();
  final TextEditingController locController = TextEditingController();
  final TextEditingController fgLocController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController rmWtController = TextEditingController();
  final TextEditingController noRemController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController segmentController = TextEditingController();
  final TextEditingController netWtController = TextEditingController();
  final TextEditingController grossWtController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController totalWeightController = TextEditingController();

  bool isLoading = false;

  List<String> fgLocations = [];
  String? selectedFgLoc;

  @override
  void initState() {
    super.initState();
    _setCurrentDprDate();
    batchController.addListener(_checkAutoFetch);
    fgLocController.addListener(_checkAutoFetch);
    fetchTargetLocations();
  }

  void _setCurrentDprDate() {
    dprDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
  }

  void _clearAfterScan() {
    batchController.clear();

    // 🔥 scanner instantly ready again
    Future.delayed(const Duration(milliseconds: 80), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> fetchTargetLocations() async {
    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/GetTargetLocation?screen1=1",
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          fgLocations = (data['locations'] as List)
              .map((e) => e.toString())
              .toList();
        });
      }
    } catch (_) {}
  }

  void _checkAutoFetch() {
    if (batchController.text.isNotEmpty &&
        (selectedFgLoc ?? "").isNotEmpty &&
        !isLoading) {
      fetchSAPData();
    }
  }

  Future<void> fetchSAPData() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/GetBarcodeData"
          "?charg=${batchController.text.trim()}"
          "&lgort=$selectedFgLoc"
          "&scanName=${widget.scannerName}",
        ),
      );

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);

        /// ✅ SHOW SUCCESS MESSAGE (LV_MESS)
        final messageElement =
            document.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? document.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Scanned successfully";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $message"),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );

        /// ✅ CONTINUE NORMAL DATA FILLING
        final items = document.findAllElements('item').toList();

        if (items.isEmpty) return;

        // SAP data is usually in second item
        final item = items.length > 1 ? items[1] : items.first;

        setState(() {
          _setCurrentDprDate();

          locController.text = item.getElement('LOCATION')?.innerText ?? '';
          rmWtController.text = item.getElement('RM_WT')?.innerText ?? '';
          noRemController.text = item.getElement('NO_REM')?.innerText ?? '';
          qtyController.text = item.getElement('QUANTITY')?.innerText ?? '';
          descController.text = item.getElement('BELOW_LOC')?.innerText ?? '';
          segmentController.text = item.getElement('SEGMENT')?.innerText ?? '';
          netWtController.text = item.getElement('NETWT')?.innerText ?? '';
          grossWtController.text = item.getElement('GROSS_WT')?.innerText ?? '';
          totalController.text = item.getElement('TOTAL')?.innerText ?? '';
          totalWeightController.text =
              item.getElement('TOTAL_WEIGHT')?.innerText ?? '';

          scanCount++;
          scanCountController.text = scanCount.toString();
        });

        _clearAfterScan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Scan failed: ${response.statusCode}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ SAP XML Error: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> postBarcodeData() async {
    if (isLoading) return;

    final lgort = selectedFgLoc; // or selectedPmLoc
    final scanName = widget.scannerName;

    if (lgort == null || lgort.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select Location")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse(
        "http://192.168.20.27:94/api/SAP/PostBarcodeData"
        "?lgort=$lgort"
        "&scanName=$scanName",
      );

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);

        final messageElement =
            xmlDoc.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Posted successfully";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $message"),
            backgroundColor: Colors.green.shade700,
          ),
        );
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
    } finally {
      setState(() => isLoading = false);
    }
  }

  void clearFields() {
    batchController.clear();
    locController.clear();
    fgLocController.clear();
    rmWtController.clear();
    noRemController.clear();
    qtyController.clear();
    segmentController.clear();
    netWtController.clear();
    grossWtController.clear();
    descController.clear();
    totalController.clear();
    totalWeightController.clear();
    selectedFgLoc = null;
    _setCurrentDprDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B5D1E),
      appBar: AppBar(
        title: const Text(
          "Stock In",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B5D1E), Color(0xFF1E7F35)],
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
                width: 480,
                height: 800,
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  // ✅ MAIN FIX
                  child: Column(
                    children: [
                      /// 🔥 BIG BATCH FIELD
                      TextFormField(
                        controller: batchController,
                        autofocus: true,
                        style: _style(fontSize: 20),
                        decoration: _decoration("Batch", scan: true),
                      ),

                      const SizedBox(height: 10),
                      _fgDropdown(),

                      const SizedBox(height: 10),

                      TextFormField(
                        controller: scanCountController,
                        enabled: false,
                        style: _style(fontSize: 18),
                        decoration: _decoration("No. of Scans"),
                      ),

                      const SizedBox(height: 10),

                      TextFormField(
                        controller: descController,
                        enabled: false,
                        style: _style(fontSize: 18),
                        decoration: _decoration("Description"),
                      ),

                      const SizedBox(height: 10),

                      /// ✅ NON-EDITABLE GRID (SCROLL SAFE)
                      SizedBox(
                        height: 420, // ✅ tuned for 800×480
                        child: GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3.8, // compact height
                          children: [
                            _field("DPR Date", dprDateController),
                            _field("Loc.", locController),
                            _field("RmWt.", rmWtController),
                            _field("No. Reams", noRemController),
                            _field("Qty.", qtyController),
                            _field("Segment", segmentController),
                            _field("NetWt.", netWtController),
                            _field("GrossWt.", grossWtController),
                            _field("Total", totalController),
                            _field("Total Weight", totalWeightController),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      /// ✅ BUTTONS ALWAYS VISIBLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _button(
                            "Post",
                            Colors.deepPurpleAccent,
                            postBarcodeData,
                          ),
                          _button("Clear", Colors.blueAccent, clearFields),
                          _button(
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

  Widget _field(String label, TextEditingController c) {
    return TextFormField(
      controller: c,
      enabled: false,
      style: _style(),
      decoration: _decoration(label),
    );
  }

  Widget _fgDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedFgLoc,
      items: fgLocations
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        setState(() {
          selectedFgLoc = v;
          fgLocController.text = v ?? "";
        });
        _checkAutoFetch();
      },
      decoration: _decoration("FG Loc.", scan: true),
      dropdownColor: const Color(0xFF1E7F35),
      style: _style(fontSize: 18),
      iconEnabledColor: Colors.white,
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

  Widget _button(String t, Color c, VoidCallback fn) {
    return ElevatedButton(
      onPressed: fn,
      style: ElevatedButton.styleFrom(
        backgroundColor: c,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
