
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:kologsoft/screens/stocking_mode.dart';
import 'package:provider/provider.dart';

import '../models/stocking_modeModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class StockingModeListPage extends StatefulWidget {
  @override
  _StockingModeListPageState createState() => _StockingModeListPageState();
}

class _StockingModeListPageState extends State<StockingModeListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  String searchQuery = '';

  void initState(){
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchStockingModes();

    });
  }

  List<cropModel> filterstockingModes(List<cropModel> stockingmodel) {
    if (searchQuery.isEmpty) return stockingmodel;

    final query = searchQuery.toLowerCase();
    return stockingmodel.where((s) {
      final Name = s.name.toLowerCase();
      final contact = s.staff.toLowerCase();
      return Name.contains(query) || contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<Datafeed>(builder: (BuildContext context, Datafeed value, Widget? child) {
      final stockmode =filterstockingModes(value.stockingModes);

      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text("Registered Stocking Mode"),
          backgroundColor: const Color(0xFF1B263B),
          actions: [

          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextFormField(
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search Warehouses...',
                      hintStyle: TextStyle(color: Colors.white54),
                      prefixIcon:
                      Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Color(0xFF22304A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 10,),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: stockmode.length,
                      itemBuilder: (context, index) {
                        final stockingMode = stockmode[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B263B),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text( stockingMode.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Staff: ${stockingMode.staff ?? ''}\nDate: ${stockingMode.date}",
                                        style: const TextStyle(
                                            color: Colors.white70, height: 1.4),
                                      ),
                                    ]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.amber),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StockingMode(
                                        docId: stockingMode.id,
                                        data: stockingMode.toMap(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Delete mode"),
                                      content: const Text(
                                          "Are you sure you want to delete this mode?"),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text("Cancel")),
                                        ElevatedButton(
                                            onPressed: () =>  Navigator.pop(context, true),
                                            child: const Text("Delete")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await db.collection('stockingmode').doc(stockingMode.id).delete();
                                    value.stockingModes.removeWhere((test) =>test.id == stockingMode.id);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("stocking mode deleted")));
                                    setState(() {}); // refresh after delete
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // FutureBuilder<List<QueryDocumentSnapshot>>(
        //   future: _getWorkspaces(),
        //   builder: (context, snapshot) {
        //     if (snapshot.connectionState == ConnectionState.waiting)
        //       return const Center(child: CircularProgressIndicator());
        //     if (snapshot.hasError)
        //       return Center(child: Text("Error: ${snapshot.error}"));
        //     if (!snapshot.hasData || snapshot.data!.isEmpty)
        //       return const Center(
        //           child: Text("No stocking mode registered yet.",
        //               style: TextStyle(color: Colors.white70, fontSize: 16)));
        //
        //     final docs = snapshot.data!;
        //
        //     return Center(
        //       child: ConstrainedBox(
        //         constraints: BoxConstraints(maxWidth: cardWidth),
        //         child: ListView.builder(
        //           padding: const EdgeInsets.all(20),
        //           itemCount: docs.length,
        //           itemBuilder: (context, index) {
        //             final doc = docs[index];
        //             final data = doc.data() as Map<String, dynamic>;
        //
        //             String createdAtStr = "";
        //             if (data['date'] != null && data['date'] is Timestamp) {
        //               DateTime dt = (data['date'] as Timestamp).toDate();
        //               createdAtStr =
        //               "${dt.weekdayName()} ${dt.day} ${dt.monthName()} ${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
        //             }
        //
        //             return Container(
        //               margin: const EdgeInsets.only(bottom: 16),
        //               padding: const EdgeInsets.all(18),
        //               decoration: BoxDecoration(
        //                 color: const Color(0xFF1B263B),
        //                 borderRadius: BorderRadius.circular(16),
        //                 boxShadow: [
        //                   BoxShadow(
        //                     color: Colors.black.withOpacity(0.15),
        //                     blurRadius: 8,
        //                     offset: const Offset(0, 4),
        //                   ),
        //                 ],
        //               ),
        //               child: Row(
        //                 children: [
        //                   Expanded(
        //                     child: Column(
        //                         crossAxisAlignment: CrossAxisAlignment.start,
        //                         children: [
        //                           Text(
        //                             data['name'] ?? "",
        //                             style: const TextStyle(
        //                                 color: Colors.white,
        //                                 fontSize: 16,
        //                                 fontWeight: FontWeight.bold),
        //                           ),
        //                           const SizedBox(height: 6),
        //                           Text(
        //                             "Staff: ${data['staff'] ?? ''}\nDate: $createdAtStr",
        //                             style: const TextStyle(
        //                                 color: Colors.white70, height: 1.4),
        //                           ),
        //                         ]),
        //                   ),
        //                   IconButton(
        //                     icon: const Icon(Icons.edit, color: Colors.amber),
        //                     onPressed: () {
        //                       Navigator.push(
        //                         context,
        //                         MaterialPageRoute(
        //                           builder: (_) => StockingMode(
        //                             docId: doc.id,
        //                             data: data,
        //                           ),
        //                         ),
        //                       );
        //                     },
        //                   ),
        //                   IconButton(
        //                     icon: const Icon(Icons.delete, color: Colors.redAccent),
        //                     onPressed: () async {
        //                       final confirm = await showDialog<bool>(
        //                         context: context,
        //                         builder: (_) => AlertDialog(
        //                           title: const Text("Delete mode"),
        //                           content: const Text(
        //                               "Are you sure you want to delete this mode?"),
        //                           actions: [
        //                             TextButton(
        //                                 onPressed: () =>
        //                                     Navigator.pop(context, false),
        //                                 child: const Text("Cancel")),
        //                             ElevatedButton(
        //                                 onPressed: () =>
        //                                     Navigator.pop(context, true),
        //                                 child: const Text("Delete")),
        //                           ],
        //                         ),
        //                       );
        //
        //                       if (confirm == true) {
        //                         await db.collection('stockingmode').doc(doc.id).delete();
        //                         ScaffoldMessenger.of(context).showSnackBar(
        //                             const SnackBar(content: Text("stocking mode deleted")));
        //                         setState(() {}); // refresh after delete
        //                       }
        //                     },
        //                   ),
        //                 ],
        //               ),
        //             );
        //           },
        //         ),
        //       ),
        //     );
        //   },
        // ),
      );
    },

    );
  }
}

