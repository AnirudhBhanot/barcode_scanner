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
  final Map<String, TextEditingController> fieldControllers = {
    "Shno.": TextEditingController(),
    "Batch": TextEditingController(),
    "DPR Date": TextEditingController(),
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

  bool isLoading = false;
  String lvMessage = "";

  @override
  void initState() {
    super.initState();
    _setCurrentDprDate();

    // 👇 Add listeners to auto-run scanData when both Batch & Shno are entered
    fieldControllers["Batch"]?.addListener(_checkAutoScan);
    fieldControllers["Shno."]?.addListener(_checkAutoScan);
  }

  void _setCurrentDprDate() {
    fieldControllers["DPR Date"]?.text =
        DateFormat('dd-MM-yyyy').format(DateTime.now());
  }

  // 👇 This function checks if both fields are filled, then triggers scanData()
  void _checkAutoScan() {
    final batch = fieldControllers["Batch"]?.text.trim() ?? "";
    final shno = fieldControllers["Shno."]?.text.trim() ?? "";

    if (batch.isNotEmpty && shno.isNotEmpty) {
      // Delay to ensure user finishes typing before triggering
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

    if (batchNo.isEmpty || shipmentNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both Shipment No and Batch.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      lvMessage = "";
    });

    try {
      final response = await http.get(Uri.parse(
          "https://localhost:7278/api/SAP/GetDoPickingData?batchNo=$batchNo&scanName=$scanName&shipmentNo=$shipmentNo"));

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);
        final items = xmlDoc.findAllElements('item').toList();
        final messageNode = xmlDoc.findAllElements('LV_MESS').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS').first.innerText
            : "No message returned";

        setState(() {
          lvMessage = messageNode;
        });

        if (items.isNotEmpty) {
          final item = items.last;
          setState(() {
            fieldControllers["Loc."]?.text =
                item.getElement('LOCATION')?.innerText ?? '';
            _setCurrentDprDate();
            fieldControllers["RmWt."]?.text =
                item.getElement('RM_WT')?.innerText ?? '';
            fieldControllers["No. Reams"]?.text =
                item.getElement('NO_REM')?.innerText ?? '';
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
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Scan complete: $messageNode")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Scan failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error scanning: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> postData() async {
    final shipmentNo = fieldControllers["Shno."]?.text.trim() ?? "";
    final scanName = widget.scannerName;

    if (shipmentNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Shipment No before posting.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      lvMessage = "";
    });

    try {
      final response = await http.post(Uri.parse(
          "https://localhost:7278/api/SAP/PostDoPickingData?shipmentNo=$shipmentNo&scanName=$scanName"));

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);
        final messageNode = xmlDoc.findAllElements('LV_MESS').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS').first.innerText
            : "No message returned";

        setState(() {
          lvMessage = messageNode;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Post complete: $messageNode")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Post failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error posting data: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void clearFields() {
    for (var key in fieldControllers.keys) {
      if (key != "DPR Date") fieldControllers[key]?.clear();
    }
    _setCurrentDprDate();
    setState(() => lvMessage = "");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cleared all fields.")),
    );
  }

  @override
  void dispose() {
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final fieldLabels = [
      "Batch",
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
      appBar: AppBar(
        title: const Text(
          "DO Picking",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0B5D1E),
      body: Container(
        width: double.infinity,
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
              final cardWidth = isMobile
                  ? screenWidth * 0.9
                  : (constraints.maxWidth * 0.5).clamp(500.0, 600.0);
              final cardHeight = isMobile ? 820.0 : 780.0;

              return Card(
                elevation: 30,
                shadowColor: Color(0xFF0B5D1E).withOpacity(0.5),
                color: Colors.white.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: fieldControllers["Shno."],
                                enabled: true,
                                decoration: InputDecoration(
                                  labelText: "Shno.",
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        const BorderSide(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0B5D1E)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              GridView.count(
                                crossAxisCount: 2,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                shrinkWrap: true,
                                childAspectRatio: isMobile ? 3.3 : 3.6,
                                children: fieldLabels.map((label) {
                                  final controller = fieldControllers[label]!;
                                  final editable = (label == "Batch");
                                  return TextFormField(
                                    controller: controller,
                                    enabled: editable,
                                    decoration: InputDecoration(
                                      labelText: label,
                                      labelStyle:
                                          const TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withOpacity(0.08),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            color: Colors.white24),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0B5D1E)),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    onEditingComplete: () {
                                      if (label == "Batch") scanData();
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildButton(
                            "Post",
                            Colors.deepPurpleAccent,
                            isLoading ? null : postData,
                          ),
                          _buildButton(
                            "Clear",
                            Colors.blueAccent,
                            isLoading ? null : clearFields,
                          ),
                          _buildButton(
                            "Back",
                            Colors.orangeAccent,
                            () => Navigator.pop(context),
                          ),
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

  Widget _buildButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
