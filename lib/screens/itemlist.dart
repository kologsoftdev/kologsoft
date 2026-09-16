import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';
import '../widgets/itemmodal.dart';
import 'itemreg.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";


  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  static const List<double> _columnWidths = [50, 180, 140, 100, 90, 100, 100, 140, 110];
  static const double _horizontalPadding = 24;
  static const double _mobileInset = 16;

  double get _totalWidth =>  _columnWidths.reduce((a, b) => a + b) + _horizontalPadding;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  List<ItemModel> _filteredItems(List<ItemModel> items) {
    if (searchQuery.isEmpty) return items;

    final query = searchQuery.toLowerCase();
    return items.where((item) {
      final name = (item.name).toLowerCase();
      final barcode = (item.barcode).toLowerCase();
      final company = (item.company).toLowerCase();
      final category = (item.pcategory).toLowerCase();

      return name.contains(query) ||
          barcode.contains(query) ||
          company.contains(query) ||
          category.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1000;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final filteredItems = _filteredItems(value.items);
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(title: const Text("Registered Items")),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemRegPage()),
              );
            },
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                _searchBar(isDesktop: isDesktop),
                Expanded(
                  child: value.loading
                      ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : filteredItems.isEmpty
                      ? const Center(
                    child: Text(
                      "No items registered yet",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : isDesktop
                      ? _desktopTable(filteredItems, value)
                      : _mobileCards(filteredItems, value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextFormField(
      onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF22304A),
        hintText: "Search...",
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.white54),
          onPressed: () => setState(() => searchQuery = ""),
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }


  Widget _searchBar({required bool isDesktop}) {
    if (!isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(
          left: _mobileInset,
          right: _mobileInset,
          top: 16,
          bottom: 8,
        ),
        child: _buildSearchField(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        // Not meant to be dragged independently — it just mirrors the
        // table's horizontal offset via the shared controller.
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: _totalWidth,
          child: _buildSearchField(),
        ),
      ),
    );
  }

  Widget _mobileCards(List<ItemModel> items, Datafeed value) {
    return ListView.builder(
      padding: const EdgeInsets.all(_mobileInset),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        try {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ItemDetailsModal(context: context, item: item).show();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF415A77),
                      child: Text("${index + 1}"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Barcode: ${item.barcode}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if(item.shelfnumber != null && item.shelfnumber!.isNotEmpty)
                          Text(
                            "Shell Number: ${item.shelfnumber}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error building item card for item ${items[index].id}: $e");
          return Container();
        }
      },
    );
  }

  Widget _desktopTable(List<ItemModel> items, Datafeed value) {
    final columnWidths = _columnWidths;
    final totalWidth = _totalWidth;

    Widget headerCell(String text, double width) {
      return SizedBox(
        width: width,
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      );
    }

    Widget bodyCell(Widget child, double width) {
      return SizedBox(width: width, child: child);
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: const Color(0xFF22304A),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      headerCell("#", columnWidths[0]),
                      headerCell("Name", columnWidths[1]),
                      headerCell("Barcode", columnWidths[2]),
                      headerCell("Cost Price", columnWidths[3]),
                      headerCell("Retail", columnWidths[4]),
                      headerCell("Wholesale", columnWidths[5]),
                      headerCell("Supplier", columnWidths[6]),
                      headerCell("Inactive/Active", columnWidths[7]),
                      headerCell("Actions", columnWidths[8]),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.builder(
                      controller: _verticalController,
                      itemCount: items.length,
                      itemExtent: 64,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final supplierPrices = item.modes
                            ?.where((d) => d.name.toLowerCase() == 'carton')
                            .map((m) => " ${m.sp}")
                            .join("\n") ??
                            "";
                        final wholesalePrices = item.modes
                            ?.where((d) => d.name.toLowerCase() == 'carton')
                            .map((m) => " ${m.wp}")
                            .join("\n") ??
                            "";
                        final singlePrices = item.modes
                            ?.where((d) => d.name.toLowerCase() == 'single')
                            .map((m) => "${m.rp}")
                            .join("\n") ??
                            "";

                        try {
                          return InkWell(
                            onTap: () => ItemDetailsModal(context: context, item: item).show(),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B263B),
                                border: Border(bottom: BorderSide(color: Color(0xFF22304A))),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  bodyCell(Text("${index + 1}", style: const TextStyle(color: Colors.white)), columnWidths[0]),
                                  bodyCell(Text(item.name, style: const TextStyle(color: Colors.white)), columnWidths[1]),
                                  bodyCell(Text(item.barcode, style: const TextStyle(color: Colors.white70)), columnWidths[2]),
                                  bodyCell(Text(item.cp, style: const TextStyle(color: Colors.white70)), columnWidths[3]),
                                  bodyCell(
                                    Tooltip(
                                      message: singlePrices,
                                      child: Text(singlePrices,
                                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                    ),
                                    columnWidths[4],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: wholesalePrices,
                                      child: Text(wholesalePrices,
                                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                    ),
                                    columnWidths[5],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: supplierPrices,
                                      child: Text(supplierPrices,
                                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                    ),
                                    columnWidths[6],
                                  ),
                                  bodyCell(
                                    Center(
                                      child: Switch(
                                        value: item.isActive == true,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          if (!mounted) return;
                                          context.read<Datafeed>().toggleNormalItemActive(docId: item.id, newStatus: val);
                                        },
                                      ),
                                    ),
                                    columnWidths[7],
                                  ),
                                  bodyCell(
                                    Row(
                                      children: [
                                        Visibility(
                                          visible: value.canEdit(AppModules.stock),
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.amber),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ItemRegPage(docId: item.id, item: item)),
                                              );
                                            },
                                          ),
                                        ),
                                        Visibility(
                                          visible: value.canDelete(AppModules.stock),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            onPressed: () => _deleteItem(item.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                    columnWidths[8],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } catch (e) {
                          print("Error building table row for item ${item.id}: $e");
                          return SizedBox(height: 64, width: totalWidth);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF182232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirm Delete",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to delete this item?\nThis action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Delete",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final provider = context.read<Datafeed>();
      final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final docRef = db.collection('itemsreg').doc(id);

      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        //deletedcollection
        await db.collection('deletedcollection').add({
          ...data,
          'originalCollection': 'itemsreg',
          'originalId': id,
          'type': 'itemsreg',
          'status': 'deleted',
          'branchid': provider.branchid,
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by': provider.staff,
          'deleted_email': provider.staffemail,
          'companyid': provider.companyid,
          'datedmy': formattedDate,
        });
        await docRef.delete();
      }

      final datafeed = context.read<Datafeed>();
      datafeed.items.removeWhere((item) => item.id == id);
      datafeed.notifyListeners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Item deleted successfully",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed to delete item: $e",
                  style: TextStyle(color: Theme.of(context).colorScheme.surface))),
        );
      }
    }
  }
}
