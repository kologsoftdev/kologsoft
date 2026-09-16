import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/supplierscreen.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/suppliermodel.dart';
import '../providers/Datafeed.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  String searchQuery = '';
  List<Supplier> _filteredSuppliers(List<Supplier> suppliers) {
    if (searchQuery.isEmpty) return suppliers;

    final query = searchQuery.toLowerCase();
    return suppliers.where((s) {
      final supplierName = s.supplier.toLowerCase();
      final contact = s.contact.toLowerCase();
      return supplierName.contains(query) || contact.contains(query);
    }).toList();
  }
  final ScrollController _scrollController = ScrollController();
  void initState(){
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchSuppliers();
    });

}
@override
void dispose(){
    super.dispose();
    _scrollController.dispose();

}
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final listWidth =  screenWidth > 900 ? screenWidth * 0.6 : screenWidth * 0.95;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredSuppliers = _filteredSuppliers(value.suppliers);

        return Scaffold(
          backgroundColor: const Color(0xFF1B263B),
          appBar: AppBar(title: const Text('Supplier List'),
            actions: [

            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  width: listWidth,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [

                      TextField(
                        onChanged: (v) => setState(() => searchQuery = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search suppliers...',
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
                      const SizedBox(height: 16),

                      // ---------- Supplier List ----------
                      Expanded(
                        child: filteredSuppliers.isEmpty
                            ? const Center(
                          child: Text('No suppliers found',style: TextStyle(color: Colors.white70)),
                        )
                         : ScrollbarTheme(
                           data: ScrollbarThemeData(
                             thumbColor: MaterialStateProperty.all(Color(0xFF415A77)),
                             trackColor: MaterialStateProperty.all(Colors.grey.shade300),
                             thickness: MaterialStateProperty.all(10),
                             radius: const Radius.circular(10),
                             thumbVisibility: MaterialStateProperty.all(true),
                           ),
                           child: Scrollbar(
                             controller: _scrollController,
                             thickness: 10,
                             thumbVisibility: true,
                             interactive: true,
                             child: ListView.separated(
                               controller: _scrollController,
                               physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredSuppliers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final supplier = filteredSuppliers[index];

                                return Card(
                                  color: const Color(0xFF22304A), // dark card background
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Numbering
                                        Text(
                                          '${index + 1}.',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Supplier info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                supplier.supplier,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Contact: ${supplier.contact}',
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Edit & Delete buttons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (value.canEdit(AppModules.settings))
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => SupplierRegistration(supplier: supplier),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (value.canDelete(AppModules.settings))
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    backgroundColor: const Color(0xFF1B263B),
                                                    title: const Text('Delete Supplier',style: TextStyle(color: Colors.white70),),
                                                    content: const Text(
                                                      'Are you sure you want to delete this supplier?',style: TextStyle(color: Colors.white70),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context, false),
                                                        child: const Text('Cancel',style: TextStyle(color: Colors.white70),),
                                                      ),
                                                      TextButton(
                                                        style:TextButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white70,
                                                        ),
                                                        onPressed: () => Navigator.pop(context, true),
                                                        child: const Text('Delete',style: TextStyle(color: Colors.white70),),
                                                      ),
                                                    ],
                                                  ),
                                                );


                                                if (confirm ?? false) {
                                                  if (!value.canDelete(AppModules.settings)) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Permission denied')),
                                                    );
                                                    return;
                                                  }
                                                  try {
                                                    await value.deleteSupplier(supplier.id);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        backgroundColor: Colors.red,
                                                        content: Text('Supplier deleted successfully',style: TextStyle(color: Colors.white),),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Failed to delete: $e')),
                                                    );
                                                  }
                                                }
                                              },
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

