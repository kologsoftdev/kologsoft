import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';
import '../screens/itemreg.dart';

class ItemDetailsModal {
  final BuildContext context;
  final ItemModel item;

  ItemDetailsModal({required this.context, required this.item});

  void show() {
    showDialog(
      context: context,
      builder: (ctx) => _ItemDetailsDialog(item: item),
    );
  }
}

class _ItemDetailsDialog extends StatefulWidget {
  final ItemModel item;
  const _ItemDetailsDialog({required this.item});

  @override
  State<_ItemDetailsDialog> createState() => _ItemDetailsDialogState();
}

class _ItemDetailsDialogState extends State<_ItemDetailsDialog> {
  late bool isActive;

  @override
  void initState() {
    super.initState();
    isActive = widget.item.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final item = widget.item;
     final provider = context.read<Datafeed>();
    return Dialog(
      backgroundColor: const Color(0xFF182232),
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        height: size.height * 0.78,
        width: size.width > 700 ? 600 : double.infinity,
        child: Column(
          children: [

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF415A77),
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : "#",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Shelf Number: ${item.shelfnumber}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          children: [
                            if (item.pcategory.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22304A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.pcategory,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              "Barcode: ${item.barcode}",
                              softWrap: true,
                              maxLines: 2,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24),

            //BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.imageurl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: ClipOval(
                            child: SizedBox(
                              height: 140,
                              width: 140,
                              child: Image.network(
                                item.imageurl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 140,
                                  width: 140,
                                  color: const Color(0xFF22304A),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    _section("Basic Information"),
                    _line("Barcode", item.barcode),

                    const SizedBox(height: 12),
                    _section("Pricing"),
                    _line("Cost Price", item.cp),

                   // _line("Retail Price", item.retailprice),
                   // _line("Wholesale Price", item.wholesaleprice),
                  //  _line("Pricing Mode", item.pricingmode),

                    const SizedBox(height: 12),
                    _section("Stock"),
                  //  _line("Opening Stock", item.openingstock),

                    _line("Supplier Minimum Quantity", item.sminqty),

                    const SizedBox(height: 12),
                    _section("Pricing Modes"),
                    if (item.modes == null || item.modes!.isEmpty)
                      const Text("No pricing modes defined", style: TextStyle(color: Colors.white54))
                    else
                      ...item.modes!.map((e) => _pricingCard(
                        name: e.name, qty: e.qty, rp: e.rp, wp: e.wp, sp: e.sp,
                      )),

                    if (item.branchprices != null && item.branchprices!.isNotEmpty)
                      ...item.branchprices!.entries.map((branchEntry) {
                        final branch = Map<String, dynamic>.from(branchEntry.value);
                        final branchName = branch['name'] ?? '';
                        final pricing = Map<String, dynamic>.from(branch['pricing'] ?? {});
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (branchName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(branchName,
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ...pricing.entries.map((e) {
                              final p = Map<String, dynamic>.from(e.value);
                              return _pricingCard(
                                name: p['name'] ?? '', qty: p['qty'] ?? '',
                                rp: p['rp'] ?? '', wp: p['wp'] ?? '', sp: p['sp'] ?? '',
                              );
                            }),
                          ],
                        );
                      }),

                    const SizedBox(height: 12),
                    _section("Audit"),
                    _line("Created At", item.createdat.toString()),
                    _line("Updated At", item.updatedat?.toString() ?? ""),
                    _line("Updated By", item.updatedby ?? ""),
                    _line("Staff", item.staff),
                  ],
                ),
              ),
            ),

            //ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Active toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Active", style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 6),
                      Switch(
                        value: isActive,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          if (!mounted) return;
                          setState(() => isActive = val);
                          context.read<Datafeed>().toggleNormalItemActive(
                            docId: item.id,
                            newStatus: val,
                          );
                        },
                      ),
                    ],
                  ),
                  // Edit button
                  Visibility(
                    visible: provider.canEdit(AppModules.stock),
                      child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A6F97)),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text("Edit", style: TextStyle(color: Colors.white70)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemRegPage(docId: item.id, item: item),
                        ),
                      );
                    },
                  )),
                  Visibility(
                    visible: provider.canDelete(AppModules.stock),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteItem(item.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 6),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _line(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label.toUpperCase(),
                style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              (value?.toString().isEmpty ?? true) ? "-" : value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingCard({required String name, required dynamic qty, required dynamic rp, required dynamic wp, required dynamic sp}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1F2A3A), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _priceBox("Quantity", qty),
              _priceBox("Retail Price", rp),
              _priceBox("Wholesale Price", wp),
              _priceBox("Supplier Price", sp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF22304A), borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(
            (value?.toString().isEmpty ?? true) ? "-" : value.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF182232),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final provider = context.read<Datafeed>();
      await provider.db.collection('itemsreg').doc(id).delete();

      final datafeed = context.read<Datafeed>();
      datafeed.items.removeWhere((item) => item.id == id);
      datafeed.notifyListeners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Item deleted successfully"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete item: $e")),
        );
      }
    }
  }
}