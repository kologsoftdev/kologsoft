
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/warehousereg.dart';
import 'package:provider/provider.dart';

import '../models/warehousemodel.dart';
import '../providers/Datafeed.dart';

class WarehouseListPage extends StatefulWidget {
  @override
  _WarehouseListPageState createState() => _WarehouseListPageState();
}

class _WarehouseListPageState extends State<WarehouseListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = '';

  void initState(){
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchWarehouses();
    });
  }

  List<WarehouseModel> filterwarehouse(List<WarehouseModel> warehouses) {
    if (searchQuery.isEmpty) return warehouses;

    final query = searchQuery.toLowerCase();
    return warehouses.where((s) {
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
      final warehouses = value.warehouses;
      final filteredWarehouses = filterwarehouse(warehouses);
      return Scaffold(
        backgroundColor: const Color(0xFF121927), // Dark background
        appBar: AppBar(
          title: const Text("Registered Warehouses"),
          backgroundColor: const Color(0xFF1B263B),
          actions: [

          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF415A77),
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseRegistration()),
            );
          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: Column(
                children: [
                  TextField(
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
                      itemCount: filteredWarehouses.length,
                      itemBuilder: (context, index) {
                        final warehouses = filteredWarehouses[index];
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
                                      Text( "${index + 1}",
                                        style: const TextStyle(color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        warehouses.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Staff: ${warehouses.staff?? ''}\nDate: ${warehouses.date}",
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
                                      builder: (_) => WarehouseRegistration(
                                        docId: warehouses.id,
                                        data: warehouses.toMap()
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
                                      backgroundColor: const Color(0xFF1B263B),
                                      title: const Text(
                                        "Delete Warehouse",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        "Are you sure you want to delete this warehouse?",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel")),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Delete")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await db.collection('warehouse').doc(warehouses.id).delete();
                                    value.warehouses.removeWhere(  (w) => w.id == warehouses.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Warehouse deleted")));
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


