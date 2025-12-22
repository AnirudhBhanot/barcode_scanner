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
  final TextEditingController batchController = TextEditingController();
  final TextEditingController dprDateController = TextEditingController();
  final TextEditingController locController = TextEditingController();
  final TextEditingController fgLocController = TextEditingController();
  final TextEditingController rmWtController = TextEditingController();
  final TextEditingController noRemController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController segmentController = TextEditingController();
  final TextEditingController netWtController = TextEditingController();
  final TextEditingController grossWtController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController totalWeightController = TextEditingController();

  bool isLoading = false;
  bool isPosting = false;

  List<String> fgLocations = [];
  String? selectedFgLoc;

  @override
  void initState() {
    super.initState();
    dprDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    batchController.addListener(_checkAutoFetch);
    fgLocController.addListener(_checkAutoFetch);
    fetchTargetLocations();
  }

  Future<void> fetchTargetLocations() async {
    try {
      final url = Uri.parse(
          "http://192.168.20.27:86/api/SAP/GetTargetLocation?screen1=1");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> locations =
            (data['locations'] as List).map((e) => e.toString()).toList();

        setState(() {
          fgLocations = locations;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Error fetching FG Locations: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching FG Locations: $e")),
      );
    }
  }

  void _checkAutoFetch() {
    final batch = batchController.text.trim();
    final fgLoc = fgLocController.text.trim();

    if (batch.isNotEmpty && fgLoc.isNotEmpty && !isLoading) {
      fetchSAPData();
    }
  }

  Future<void> fetchSAPData() async {
    final batch = batchController.text.trim();
    final fgLoc = selectedFgLoc ?? "";
    final scanName = widget.scannerName;

    if (batch.isEmpty || fgLoc.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
          "http://192.168.20.27:86/api/SAP/GetBarcodeData?charg=$batch&lgort=$fgLoc&scanName=$scanName");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);
        final items = xmlDoc.findAllElements('item').toList();

        if (items.length > 1) {
          final item = items[1];
          setState(() {
            locController.text = item.getElement('LOCATION')?.innerText ?? '';
            dprDateController.text =
                DateFormat('dd-MM-yyyy').format(DateTime.now());
            noRemController.text = item.getElement('NO_REM')?.innerText ?? '';
            rmWtController.text = item.getElement('RM_WT')?.innerText ?? '';
            segmentController.text =
                item.getElement('SEGMENT')?.innerText ?? '';
            qtyController.text =
                item.getElement('QUANTITY')?.innerText ?? '';
            netWtController.text =
                item.getElement('NETWT')?.innerText ?? '';
            grossWtController.text =
                item.getElement('GROSS_WT')?.innerText ?? '';
            totalController.text =
                item.getElement('TOTAL')?.innerText ?? '';
            totalWeightController.text =
                item.getElement('TOTAL_WEIGHT')?.innerText ?? '';
          });
        }
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Stock In",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0B5D1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B5D1E), Color(0xFF1E7F35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = isMobile
                  ? screenWidth * 0.9
                  : (constraints.maxWidth * 0.5)
                      .clamp(500.0, 600.0)
                      .toDouble(); // ✅ FIXED num→double

              final double cardHeight = isMobile ? 750.0 : 700.0;

              return Card(
                elevation: 30,
                shadowColor: Color(0xFF0B5D1E).withOpacity(0.5),
                color: Colors.white.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isMobile ? 3.2 : 3.8,
                          children: [
                            buildTextField("Batch", batchController),
                            buildTextField("DPR Date", dprDateController,
                                editable: false),
                            buildTextField("Loc.", locController,
                                editable: false),
                            buildDropdownField(),
                            buildTextField("RmWt.", rmWtController,
                                editable: false),
                            buildTextField("No. Reams", noRemController,
                                editable: false),
                            buildTextField("Qty.", qtyController,
                                editable: false),
                            buildTextField("Segment", segmentController,
                                editable: false),
                            buildTextField("NetWt.", netWtController,
                                editable: false),
                            buildTextField("GrossWt.", grossWtController,
                                editable: false),
                            buildTextField("Total", totalController,
                                editable: false),
                            buildTextField("Total Weight",
                                totalWeightController,
                                editable: false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildButton("Post", Colors.deepPurpleAccent, () {}),
                          _buildButton("Clear", Colors.blueAccent, () {}),
                          _buildButton("Back", Colors.orangeAccent, () {
                            Navigator.pop(context);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: selectedFgLoc,
      items: fgLocations
          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedFgLoc = value;
          fgLocController.text = value ?? "";
        });
      },
      decoration: inputDecoration("FG Loc."),
      dropdownColor: Color.fromARGB(255, 22, 187, 61),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool editable = true}) {
    return TextFormField(
      controller: controller,
      enabled: editable,
      decoration: inputDecoration(label),
      style: const TextStyle(color: Colors.white),
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF0B5D1E),),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 6,
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
