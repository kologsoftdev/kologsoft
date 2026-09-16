import 'package:flutter/material.dart';

class ReceiptDashboardScreen extends StatelessWidget {
  const ReceiptDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Column(
        children: [
          // ================= TOP BANNER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF004E64), Color(0xFF00A5CF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Center(
              child: Text(
                "WELCOME TO KOLOGSOFT POS. PLEASE PAYMENT IS MADE BEFORE RECEIPT OR INVOICE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ================= TABLE SECTION =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // ================= CONTROLS ROW =================
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text("Show "),
                          SizedBox(
                            width: 80,
                            child: DropdownButtonFormField<int>(
                              value: 10,
                              items: const [
                                DropdownMenuItem(
                                    value: 10, child: Text("10")),
                                DropdownMenuItem(
                                    value: 25, child: Text("25")),
                                DropdownMenuItem(
                                    value: 50, child: Text("50")),
                              ],
                              onChanged: (_) {},
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding:
                                EdgeInsets.symmetric(horizontal: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const Text("entries"),

                          const Spacer(),

                          ElevatedButton(
                            onPressed: () {},
                            child: const Text("Copy"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text("CSV"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text("Print"),
                          ),

                          const SizedBox(width: 40),

                          const Text("Search: "),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // ================= DATA TABLE =================
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1200,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 30,
                              headingRowColor:
                              MaterialStateProperty.all(Colors.grey[200]),
                              columns: const [
                                DataColumn(label: Text("#")),
                                DataColumn(label: Text("Date")),
                                DataColumn(label: Text("Time")),
                                DataColumn(label: Text("Receipt Number")),
                                DataColumn(label: Text("Total Amount")),
                                DataColumn(label: Text("Printed staff")),
                                DataColumn(label: Text("Receipted staff")),
                                DataColumn(label: Text("Staff")),
                                DataColumn(label: Text("Customer")),
                                DataColumn(label: Text("Transmode")),
                                DataColumn(label: Text("Invoice")),
                                DataColumn(label: Text("Receipt")),
                              ],
                              rows: const [],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // ================= BOTTOM INFO =================
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: const [
                          Text("Showing 0 to 0 of 0 entries"),
                          Spacer(),
                          Text("Previous"),
                          SizedBox(width: 16),
                          Text("Next"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ================= FOOTER =================
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              "KologSoft ©2026",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}