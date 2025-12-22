import 'package:flutter/material.dart';
import 'stock_in.dart';
import 'stock_reversal.dart';
import 'do_picking.dart';

class HomePage extends StatelessWidget {
  final String? scannerName;
  const HomePage({super.key, this.scannerName});

  @override
  Widget build(BuildContext context) {
    final tileIcons = [
      Icons.add_circle,
      Icons.indeterminate_check_box,
      Icons.add_shopping_cart,
    ];

    final tileLabels = [
      "Stock In",
      "Stock Reversal",
      "DO Picking",
    ];

    final tileRoutes = [
      StockInPage(scannerName: scannerName ?? "",),
      StockReversalPage(scannerName: scannerName ?? "",),
      DoPickingPage(scannerName: scannerName ?? "",),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      backgroundColor: const Color(0xFF0B5D1E),

      // ✅ GREEN GRADIENT BACKGROUND MATCHING MAIN.DART
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B5D1E), Color(0xFF1E7F35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: isMobile ? screenWidth * 0.92 : 500,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
            ),

            // ✅ CLEAN 3-TILE LAYOUT
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tileIcons.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 22,
                crossAxisSpacing: 22,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => tileRoutes[index]),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0B5D1E),
                          Color(0xFF1E7F35),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(3, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tileIcons[index],
                          size: isMobile ? 44 : 52,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tileLabels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
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
}
