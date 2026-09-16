import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../../providers/SalesProvider.dart';

class HamperSection extends StatefulWidget {
  final Datafeed datafeed;
  final String activeBranchId;
  final String activeBranchName;

  const HamperSection({super.key,
    required this.datafeed,
    required this.activeBranchId,
    required this.activeBranchName,
  });

  @override
  State<HamperSection> createState() => _HamperSectionState();
}

class _HamperSectionState extends State<HamperSection> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _query = '';
  ItemModel ? _selectedBundle;
  bool _isAdding = false;


  String branchid = "";
  String branchtype = "";
  String? cp;
  Map<String, dynamic>? branchbalance;
  void _snackMsg(String msg, Color color,  {Duration dur = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, duration: dur,
    ));
  }

  @override
  void initState() {
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchbundlesales();
    });
    _searchCtrl.addListener(
          () => setState(() => _query = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<ItemModel> get _bundles => widget.datafeed
      .bundleviewitemodel.where((b) => b.isActive == true).where((b) =>
      _query.isEmpty ||
      (b.name).toString().toLowerCase().contains(_query.toLowerCase()) ||
      (b.barcode).toString().toLowerCase().contains(_query.toLowerCase()))
      .toList();



  void _addBundleToCart() {
    if (_selectedBundle == null) return;

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1;

    if (qty <= 0) {
      _snackMsg("Quantity is less than 1", Colors.red);
      return;
    }

    final bundleslist = (_selectedBundle?.items as List?) ?? [];

    if (bundleslist.isEmpty) {
      _snackMsg('Bundle has no items', Colors.red);
      return;
    }

    final datafeed = context.read<Datafeed>();
    final salesProvider = context.read<SalesProvider>();

    /// STOCK CHECK
    for (final bundleItem in bundleslist) {
      final itemId = bundleItem['itemid'];

      ItemModel? realItem;
      try {
        realItem = datafeed.items.firstWhere((i) => i.id == itemId);
      } catch (_) {
        realItem = null;
      }

      if (realItem == null) {
        _snackMsg('Item not found: $itemId', Colors.red);
        return;
      }

      final bundleQty =
          double.tryParse(bundleItem['totalpieces']?.toString() ?? '1') ?? 1;

      final requiredQty = bundleQty * qty;

      final branchBalance = salesProvider.resolveBranchBalance(
        realItem.branchbalance,
        widget.activeBranchId,
        datafeed,
      );

      final availablePieces =
      salesProvider.parseNetPieces(branchBalance);

      if (requiredQty > availablePieces) {
        _snackMsg(
          'Insufficient stock for ${realItem.name} (${availablePieces.toStringAsFixed(0)} available)',
          Colors.red,
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isAdding = true);
    }

    int added = 0;
    for (final bundle in bundleslist) {
      // bundle  qty × number of bundles ordered

      final bundlepiece = double.tryParse(bundle['totalpieces']?.toString() ?? '1') ?? 1;
      final amount = double.tryParse(bundle['totalamount']?.toString() ?? '1') ?? 1;
      final totalpiece = bundlepiece * qty;
      final totalamount =  amount* qty;
      final modeqtyRaw = bundle['modeqty'] ??  '1';
      final modeqty = double.tryParse(modeqtyRaw.toString()) ?? 1;

      final unitPrice = bundle['price']?.toString() ?? '0';


      salesProvider.addToSalesPreview({
        'itemid': bundle['itemid'] ?? '',
        'branchid': widget.activeBranchId,
        'branchname': widget.activeBranchName,
        'branchtype': widget.activeBranchName,
        'modeqty': modeqty.toString(),
        //'item': '${bundle['item']} ($bundlepiece in ${_selectedBundle?.name ?? ''})',
        'item': '${bundle['item']} ( ${_selectedBundle?.name ?? ''})',
        'barcode': bundle['barcode'] ?? '',
        'mode': '${bundle['mode'] ?? 'single'}',
        'quantity':   '$totalpiece' ,
        'price': unitPrice,
        'discount': bundle['discount']?.toString() ?? '0',
        'cp': bundle['cp'] ?? '0',
        'totalpieces': totalpiece.toString(),
        'totalamount': totalamount.toStringAsFixed(2),
        'pricemode': bundle['pricemode'] ?? 'retail',
        'bundle'   :_selectedBundle?.id??'',
        'bundleName': _selectedBundle!.name,
        'pcategory': _selectedBundle?.pcategory??'',
        'producttype': _selectedBundle?.producttype??'',
      });
      added++;
    }
  if(mounted){
    setState(() {
      _isAdding = false;
      _selectedBundle = null;
      _searchCtrl.clear();
      _qtyCtrl.text = '1';
      _query = '';
    });
  }

    _snackMsg('Bundle added to cart', Colors.green);
  }
  InputDecoration _decorateInputField(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white70, fontSize: 13),
    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
    filled: true,
    fillColor: const Color(0xFF22304A),
    contentPadding: const EdgeInsets.symmetric(vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.blue, width: 1.5),
    ),
    suffixIcon: _query.isNotEmpty
        ? IconButton(
      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
      onPressed: () {
        _searchCtrl.clear();
        setState(() => _selectedBundle = null);
      },
    )
        : null,
  );

  @override
  Widget build(BuildContext context) {

    final bundles = _bundles;
    final hasSel = _selectedBundle != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Bundle',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search box
        TextFormField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _decorateInputField('Search bundle or hamper name…'),
        ),

        // Suggestions
        if (_query.isNotEmpty && !hasSel && bundles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF22304A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bundles.length,
              itemBuilder: (_, i) {
                final b = bundles[i];
                final count = (b.items as List?)?.length ?? 0;

                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 18,
                  ),
                  title: Text(
                    (b.name).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '$count item(s)',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedBundle = b;
                      _searchCtrl.text = (b.name).toString();
                      _query = '';
                    });
                  },
                );
              },
            ),
          ),

        if (_query.isNotEmpty && !hasSel && bundles.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'No bundles found',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),

        //Selected bundle + qty + Add button
        if (hasSel) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.card_giftcard,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                   (_selectedBundle?.name ?? '').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Qty stepper
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final v = (int.tryParse(_qtyCtrl.text) ?? 1) - 1;
                    _qtyCtrl.text = (v < 1 ? 1 : v).toString();
                  },
                ),
                SizedBox(
                  width: 48,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF22304A),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final v = (int.tryParse(_qtyCtrl.text) ?? 1) + 1;
                    _qtyCtrl.text = v.toString();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isAdding ? null : _addBundleToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF22304A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isAdding
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}