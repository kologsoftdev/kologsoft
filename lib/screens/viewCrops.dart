
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../models/cropModel.dart';
import '../providers/StockProvider.dart';
import 'crop_registration.dart';

class CropListPage extends StatefulWidget {
  @override
  _CropListPageState createState() => _CropListPageState();
}

class _CropListPageState extends State<CropListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  String searchQuery = '';

  void initState(){
    super.initState();
    Future.microtask((){
      context.read<StockProvider>().fetchCrops();

    });
  }

  List<CropModel> filtercops(List<CropModel> croplist) {
    if (searchQuery.isEmpty) return croplist;

    final query = searchQuery.toLowerCase();
    return croplist.where((s) {
      final Name = s.name.toLowerCase();
      final contact = s.staff.toLowerCase();
      return Name.contains(query) || contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<StockProvider>(builder: (BuildContext context, StockProvider value, Widget? child) {
      final registeredcrops =filtercops(value.crops);

      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text("Registered crops"),
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
                      hintText: 'Search crops...',
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
                      itemCount: registeredcrops.length,
                      itemBuilder: (context, index) {
                        final stockingMode = registeredcrops[index];

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
                                      builder: (_) =>CropRegistration (
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
                                    await db.collection('crops').doc(stockingMode.id).delete();
                                    value.crops.removeWhere((test) =>test.id == stockingMode.id);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("crop deleted")));
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
      );
    },

    );
  }
}

