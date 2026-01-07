import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';
import 'dart:convert';

class StockReversalPage extends StatefulWidget {
  final String scannerName;
  const StockReversalPage({super.key, required this.scannerName});

  @override
  State<StockReversalPage> createState() => _StockReversalPageState();
}

class _StockReversalPageState extends State<StockReversalPage> {
  int scanCount = 0;
  final TextEditingController scanCountController = TextEditingController(
    text: "0",
  );

  final TextEditingController batchController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  // Field controllers (non-editable)
  final Map<String, TextEditingController> fieldControllers = {
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

  String selectedRem = "";
  List<String> remList = [];

  String selectedOption = "";
  bool isLoading = false;

  // PM Loc dropdown list and selection
  List<String> pmLocList = [];
  String? selectedPmLoc;

  final FocusNode batchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _setCurrentDprDate();
    fetchRemList();
    fetchTargetLocations();
    batchController.addListener(_checkAutoFetch);
  }

  void _setCurrentDprDate() {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);
    fieldControllers["DPR Date"]?.text = formattedDate;
  }

  void _checkAutoFetch() {
    final batch = batchController.text.trim();
    final pmLoc = selectedPmLoc ?? "";
    if (batch.isNotEmpty && pmLoc.isNotEmpty && !isLoading) {
      scanData();
    }
  }

  void _clearAfterScan() {
    fieldControllers["Batch"]?.clear();

    // 🔥 scanner instantly ready again
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) batchFocus.requestFocus();
    });
  }

  // ✅ Fetch Target Location list for screen = 2
  Future<void> fetchTargetLocations() async {
    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/GetTargetLocation?screen1=2",
        ),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        List<String> locations = List<String>.from(
          jsonResponse["locations"] ?? [],
        );

        setState(() {
          pmLocList = locations;
        });
      } else {
        throw Exception("Failed to fetch PM Locations");
      }
    } catch (e) {
      debugPrint("Error fetching PM locations: $e");
    }
  }

  Future<void> fetchRemList() async {
    try {
      final response = await http.get(
        Uri.parse("http://192.168.20.27:94/api/SAP/GetStockOutRem"),
      );

      if (response.statusCode == 200) {
        List<String> items = [];
        final xmlData = response.body;
        final regex = RegExp(r"<REM_DROP>(.*?)<\/REM_DROP>");
        for (final match in regex.allMatches(xmlData)) {
          items.add(match.group(1)?.trim() ?? "");
        }

        setState(() {
          remList = items;
        });
      } else {
        throw Exception("Failed to fetch REM list");
      }
    } catch (e) {
      debugPrint("Error fetching REM: $e");
    }
  }

  Future<void> scanData() async {
    final charg = batchController.text.trim();
    final lgort = selectedPmLoc ?? "";
    final scanName = widget.scannerName;

    if (charg.isEmpty || lgort.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          "http://192.168.20.27:94/api/SAP/GetBarcodeData?charg=$charg&lgort=$lgort&scanName=$scanName",
        ),
      );

      if (response.statusCode == 200) {
        final xmlDoc = xml.XmlDocument.parse(response.body);

        final messageElement =
            xmlDoc.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Scanned successfully";

        final items = xmlDoc.findAllElements('item').toList();

        if (items.length > 1) {
          final item = items[1];
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

            descController.text = item.getElement('BELOW_LOC')?.innerText ?? '';

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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No data found for this Batch No")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error scanning data: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> postData() async {
    final rem = selectedRem; // The selected REM value from dropdown
    final selectedType = selectedOption; // Copier / Repack / Reprocess
    final pmLoc = selectedPmLoc ?? ""; // Selected PM Location
    final scanName = widget.scannerName; // Scanner name or device ID
    const operation = "P"; // "P" when posting (will be "S" by default for scan)

    // Validate required fields
    if (rem.isEmpty || selectedType.isEmpty || pmLoc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields before posting."),
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(
        "http://192.168.20.27:94/api/SAP/PostStockReversalData"
        "?rem=$rem"
        "&selectedType=$selectedType"
        "&pmLoc=$pmLoc"
        "&scanName=$scanName"
        "&operation=$operation",
      );

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final rawXml = response.body.trim();
        final xmlDoc = xml.XmlDocument.parse(rawXml);

        final messageElement =
            xmlDoc.findAllElements('LV_MESS', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS', namespace: '*').first
            : null;

        final messageTypeElement =
            xmlDoc.findAllElements('LV_MESS_TYPE', namespace: '*').isNotEmpty
            ? xmlDoc.findAllElements('LV_MESS_TYPE', namespace: '*').first
            : null;

        final message =
            messageElement?.innerText.trim() ?? "Unknown SAP Response";
        final messageType =
            messageTypeElement?.innerText.trim().toUpperCase() ?? "";

        if (messageType == "S" || message.contains("Successful")) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("✅ $message")));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("❌ $message")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error posting data: ${response.statusCode} - ${response.reasonPhrase}",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error posting to SAP: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Stock Reversal",
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
      body: SafeArea(
        child: Container(
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
                return Card(
                  elevation: 30,
                  shadowColor: Color(0xFF0B5D1E).withOpacity(0.5),
                  color: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: MediaQuery.of(context).size.height * 0.88,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Dropdown for REM
                          DropdownButtonFormField<String>(
                            value: selectedRem.isEmpty ? null : selectedRem,
                            dropdownColor: const Color.fromARGB(255, 67, 133, 58),
                            decoration: InputDecoration(
                              labelText: "Rem.",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color.fromARGB(255, 40, 107, 51),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            items: remList
                                .map(
                                  (rem) => DropdownMenuItem(
                                    value: rem,
                                    child: Text(
                                      rem,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => selectedRem = value ?? ""),
                          ),

                          const SizedBox(height: 8),

                          // Radio Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildRadio("Reprocess"),
                              _buildRadio("Repack"),
                              _buildRadio("Copier"),
                            ],
                          ),

                          const SizedBox(height: 10),

                          _buildBatchField(),
                          const SizedBox(height: 8),

                          // ✅ PM Loc Dropdown
                          DropdownButtonFormField<String>(
                            value: selectedPmLoc,
                            dropdownColor: Color(0xFF0B5D1E),
                            decoration: InputDecoration(
                              labelText: "PM Loc.",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFF0B5D1E),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            items: pmLocList
                                .map(
                                  (loc) => DropdownMenuItem(
                                    value: loc,
                                    child: Text(
                                      loc,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPmLoc = value;
                                _checkAutoFetch();
                              });
                            },
                          ),

                          const SizedBox(height: 8,),

                          _buildDescField(),

                          const SizedBox(height: 8,),

                          _buildScanField(),

                          const SizedBox(height: 8),

                          // Non-editable fields
                          GridView.builder(
                            shrinkWrap: true,
                            itemCount: fieldControllers.length,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio:
                                      3.4, // ✅ shorter fields, better fit
                                ),
                            itemBuilder: (context, index) {
                              final entry = fieldControllers.entries.elementAt(
                                index,
                              );
                              return _buildTextField(
                                entry.key,
                                entry.value,
                                false,
                              );
                            },
                          ),

                          const SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildButton(
                                "Post",
                                Colors.deepPurpleAccent,
                                postData,
                              ),
                              _buildButton("Clear", Colors.blueAccent, () {
                                batchController.clear();
                                selectedPmLoc = null;
                                fieldControllers.values.forEach(
                                  (c) => c.clear(),
                                );
                                _setCurrentDprDate();
                                setState(() {
                                  selectedOption = "";
                                  selectedRem = "";
                                });
                              }),
                              _buildButton("Back", Colors.orangeAccent, () {
                                Navigator.pop(context);
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: label,
          groupValue: selectedOption,
          onChanged: (value) => setState(() => selectedOption = value!),
          activeColor: Color(0xFF0B5D1E),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildBatchField() {
    return TextFormField(
      controller: batchController,
      autofocus: true, // 🔥 critical for scanner
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: "Batch",
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18, // BIG height = reliable scan
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 52, 128, 68),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDescField() {
    return TextFormField(
      controller: descController,
      enabled: false,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: "Description",
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18, // BIG height = reliable scan
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 44, 117, 54),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildScanField() {
    return TextFormField(
      controller: scanCountController,
      enabled: false,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: "No of Scans",
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18, // BIG height = reliable scan
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 44, 117, 54),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        elevation: 6,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Widget _buildTextField(
  String label,
  TextEditingController controller,
  bool isEditable,
) {
  return TextFormField(
    controller: controller,
    enabled: isEditable,
    readOnly: !isEditable,
    maxLines: 1,
    style: TextStyle(
      color: Colors.white,
      fontSize: 14, // ✅ compact for 800×480
      fontWeight: isEditable ? FontWeight.w600 : FontWeight.w400,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 10, // ✅ reduced height
        horizontal: 10,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Colors.deepPurpleAccent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
