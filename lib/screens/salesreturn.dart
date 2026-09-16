
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/salesreturnmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/salesreturnlist.dart';
import 'package:provider/provider.dart';

class Salesreturn extends StatefulWidget {
  final salereturn? salesitem;
  const Salesreturn({super.key, this.salesitem});

  @override
  State<Salesreturn> createState() => _SalesreturnState();
}

class _SalesreturnState extends State<Salesreturn> {
  final TextEditingController _searchController = TextEditingController();

  String? _receiptId;
  String? _transMode;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _receiptLocked = false;
  String? _searcherror;
  Timer? _debounce;
  double _amountPaid = 0;
 String?_dateymd;
  String? _selectedConditionId;
  Map<String, Map<String, dynamic>> _cartItems = {};
  List<Map<String, dynamic>> _receiptItems = [];
  List<Map<String, dynamic>> _payments = [];
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final datafeed = context.read<Datafeed>();
      datafeed.fetchItems();
      datafeed.fetchReturnreasons();
      datafeed.getdata();

      if (mounted && datafeed.returnitemreasons.isNotEmpty) {
        setState(() {
          _selectedConditionId = datafeed.returnitemreasons.first.id;
        });
      }

      if (widget.salesitem != null) {
        _receiptId = widget.salesitem!.id;
        _dateymd =widget.salesitem!.dateymd;
        print(_dateymd);
        final Map<String, dynamic> itemsMap = widget.salesitem!.items ?? {};
        setState(() {
          _cartItems = itemsMap.map(
                (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetAll(Datafeed df) {
    setState(() {
      _receiptLocked = false;
      _searchController.clear();
      df.salesItem.clear();
      _receiptId = null;
      _transMode = null;
      _amountPaid = 0;
      _dateymd='';
      _payments = [];
      _isSearching = false;
      _searcherror = null;
      _receiptItems = [];
      _cartItems = {};
      _selectedConditionId = df.returnitemreasons.isNotEmpty ? df.returnitemreasons.first.id : null;
    });
  }

  Future<void> _searchReceipt(Datafeed df, String val) async {
    setState(() {
      _isSearching = true;
      _searcherror = null;
      _receiptLocked = false;
      _receiptItems = [];
    });

    try {
      // strip leading zero then build doc id
      final cleanval = val.startsWith('0') ? val.substring(1) : val;
      final docId = "${df.companyid.toUpperCase()}_${df.staffPosition}_$cleanval";

      await df.fetchsalesitem(docId);

      final fetchedItems = List<Map<String, dynamic>>.from(df.salesItem);

      if (fetchedItems.isEmpty) {
        setState(() {
          _searcherror = "Receipt not found";
          _receiptLocked = false;
        });
        return;
      }
      final bool alreadyReturned = fetchedItems.first['returned_isreturned'] == true;
      if (alreadyReturned) {
        final String returnedDate =
            fetchedItems.first['returned_isreturned_dateymd']?.toString() ?? '';
        setState(() {
          _searcherror = returnedDate.isNotEmpty
              ? "Receipt already returned on $returnedDate"
              : "This receipt has already been returned";
          _receiptLocked = false;
          _receiptItems = [];
        });
        return;
      }
      // filter out already returned items
      final unreturned = fetchedItems.where((item) {
        final status = item['returnstatus']?.toString();
        final rtype = item['returned_type']?.toString();
        return status != 'returned' && rtype != 'Full';
      }).toList();

      if (unreturned.isEmpty) {
        setState(() {
          _searcherror = "All items in this receipt have already been returned";
          _receiptLocked = false;
          _receiptItems = [];
        });
        return;
      }

      // capture transMode from first item
      _transMode = fetchedItems.first['returned_transMode']?.toString()
          ?? fetchedItems.first['transMode']?.toString();

      final rawAmountPaid = fetchedItems.first['returned_amountPaid'];
      _amountPaid = double.tryParse(rawAmountPaid?.toString() ?? '0') ?? 0;
     _dateymd = fetchedItems.first['returned_dateymd']?? '';
      final rawPayments = fetchedItems.first['returned_payments']
          ?? fetchedItems.first['payments'];
      _payments = rawPayments is List
          ? rawPayments.map((p) => Map<String, dynamic>.from(p as Map)).toList()
          : [];

      setState(() {
        _receiptItems = unreturned;
        _receiptId = val;
        _receiptLocked = true;
        _searcherror = null;
      });
    } catch (e) {
      setState(() {
        _searcherror = "Error searching receipt";
        _receiptLocked = false;
      });
      debugPrint("Search error: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }


  void _addAllToCart(Datafeed df) {
    final reason = df.returnitemreasons.where((r) => r.id == _selectedConditionId).firstOrNull;

    if (_receiptItems.isEmpty) return;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a return reason first"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Map<String, Map<String, dynamic>> newCart = {};

    for (final item in _receiptItems) {
      final String key = item['itemkey']?.toString() ?? item['returned_itemid'].toString();
      final double qty = double.tryParse(item['returned_quantity']?.toString() ?? '0') ?? 0;
      final double price = double.tryParse(item['returned_price']?.toString() ?? '0') ?? 0;
      final double grosstotalamount = double.tryParse(item['returned_grosstotalamount']?.toString() ?? '0') ?? 0;
      final String totalAmount = (grosstotalamount).toStringAsFixed(2);

      newCart[key] = {
        'itemkey': key,
        'returned_item': item['returned_item'],
        'returned_itemid': item['returned_itemid'],
        'returned_branchid': item['returned_branchid'],
        'returned_branchname': item['returned_branchname'],
        'returned_branchtype': item['returned_branchtype'],
        'returned_cp': item['returned_cp'],
        'returned_modeqty': item['returned_modeqty'],
        'returned_pricemode': item['returned_pricemode'],
        'returned_totalpieces': item['returned_totalpieces'],
        'returned_mode': item['returned_mode'],
        'returned_grosstotalamount': item['returned_grosstotalamount'],
        'returned_discount': item['returned_discount'],
        'returned_profit': item['returned_profit'],
        'returned_barcode': item['returned_barcode'],
        'returned_pcategory': item['returned_pcategory'],
        'returned_producttype': item['returned_producttype'],
        'returned_stockCheckStatus': item['returned_stockCheckStatus'],

        'returned_receiptid': _receiptId ?? '',
        'returned_quantity': qty.toString(),
        'returned_price': price.toString(),
        'returned_transMode': item['returned_transMode'] ?? _transMode ?? '',
        'returned_condition':reason?.name?? '',
        'returned_type': 'Full',
        'status': 'returned',
        'returned_totalamount': item['returned_totalamount'],
        'returned_boxpiece': item['returned_boxpiece'] ?? '1',
      };
    }

    setState(() {
      _cartItems = newCart;
      _receiptItems = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${newCart.length} item(s) added to return cart"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(String key, Datafeed df) {
    final removed = _cartItems.remove(key);
    if (removed != null) {
      _receiptItems.add(Map<String, dynamic>.from(removed));
    }
    setState(() {});
  }

  Future<void> _saveReturn(Datafeed datafeed) async {
    if (_cartItems.isEmpty) return;

    _receiptId ??= _searchController.text.trim();

    if (_receiptId == null || _receiptId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Receipt ID is missing. Cannot save return."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
     // final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String formattedDate = _dateymd!;
      final now = DateTime.now();
      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
      final week = '${now.year}.$weekNumber';

      final cleanReceipt = _receiptId!.trim();

      if (cleanReceipt.isEmpty || cleanReceipt == 'null' || cleanReceipt.length < 2) {
        throw Exception("Invalid receipt ID");
      }

      final receipt = cleanReceipt.startsWith('0')
          ? cleanReceipt.substring(1)
          : cleanReceipt;

      final String id =
          "${datafeed.companyid.toUpperCase()}_${datafeed.staffPosition}_$receipt";

      // strip internal helper keys before saving
      Map<String, dynamic> cleanedCart() {
        final Map<String, dynamic> cleaned = {};
        _cartItems.forEach((key, value) {
          final item = Map<String, dynamic>.from(value);
          item.remove('original_item');
          cleaned[key] = item;
        });
        return cleaned;
      }

      final cart = cleanedCart();

      final firstCartItem = _cartItems.values.first;
      final returnBranchId   = firstCartItem['returned_branchid']   ?? datafeed.activeBranchId;
      final returnBranchName = firstCartItem['returned_branchname'] ?? datafeed.activeBranchName;

      final double totalAmount = _cartItems.values.fold(
        0.0,
            (sum, item) => sum + (double.tryParse(item['returned_grosstotalamount'].toString()) ?? 0),
      );
      final double totaldiscount = _cartItems.values.fold(
        0.0,
            (sum, item) => sum + (double.tryParse(item['returned_discount'].toString()) ?? 0),
      );
      final amountPaid = _amountPaid;


      final returnData = {
        'returned_companyid': datafeed.companyid,
        'returned_id': id,
        'returned_receiptid': _receiptId ?? '',
        'returned_branchid': returnBranchId,
        'returned_branchname': returnBranchName,
        'returned_createdat': FieldValue.serverTimestamp(),
        'returned_createdby': datafeed.staff,
        'returned_staffreturnedbranch': datafeed.activeBranchId,
        'returned_staffreturnedbranchname': datafeed.activeBranchName,
        'returned_updatedby': datafeed.staff,
        'returned_itemcount': _cartItems.length,
        'day': day,
        'week': week,
        'month': month,
        'year': year,
        'transmode': _transMode ?? cart.values.first['returned_transMode'] ?? '',
        'dateymd': formattedDate,
        'returned_items': cart,
        'returned_transMode': _transMode,
        'returned_grosstotalamount': totalAmount,
        'returned_discount': totaldiscount,
        'returned_amountPaid': amountPaid,
        'returned_payments': _payments,
        'returned_updatedat': FieldValue.serverTimestamp(),
        'returned_staff': datafeed.staff,
        'returned_timestamp': DateTime.now().millisecondsSinceEpoch,
        'staffemail': datafeed.staffemail,
      };

      final updateData = {
        'isreturned': true,
        'isreturned_dateymd': formattedDate,
        'returned_updatedat': FieldValue.serverTimestamp(),
        'returned_updatedby': datafeed.staff,
        'items': cart,
        'staffemailupdated': datafeed.staffemail,
      };

      await datafeed.db
          .collection('sales')
          .doc(id)
          .set(updateData, SetOptions(merge: true));

      await datafeed.db.collection('salesreturn').doc(id)
          .set(returnData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text("Return saved successfully",style:TextStyle(
              color:ColorScheme.of(context).onPrimary ),),
          backgroundColor: Colors.green,
        ),
      );

      _resetAll(datafeed);

      if (widget.salesitem != null) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e",style:
          TextStyle(color: ColorScheme.of(context).onPrimary),),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F18),
      appBar: AppBar(
        title: const Text(
          "Sales Returns",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _resetAll(datafeed);
            Navigator.pop(context);
          },
        ),
        backgroundColor: const Color(0xFF151F2E),
        elevation: 2,
        shadowColor: Colors.black45,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 6,
        icon: const Icon(Icons.view_list, color: Colors.white),
        label: const Text(
          'View History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesreturnListPage()),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: _buildLeftPanel(datafeed),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _buildCartList(datafeed),
                              const SizedBox(height: 24),
                              _buildSummaryCard(),
                              const SizedBox(height: 16),
                              _buildSaveButton(datafeed),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildLeftPanel(datafeed),
                        const SizedBox(height: 24),
                        _buildCartList(datafeed),
                        const SizedBox(height: 24),
                        _buildSummaryCard(),
                        const SizedBox(height: 20),
                        _buildSaveButton(datafeed),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildLeftPanel(Datafeed df) {
    return Card(
      color: const Color(0xFF131F2C),
      elevation: 4,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER
            const Text(
              "Search Receipt",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // ── SEARCH FIELD
            TextField(
              controller: _searchController,
              readOnly: _receiptLocked,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
              cursorColor: Colors.white,
              decoration: _fieldInput("Receipt Number", Icons.search).copyWith(
                suffixIcon: _receiptLocked
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  tooltip: 'Clear',
                  onPressed: () => _resetAll(df),
                )
                    : IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () async {
                    final val = _searchController.text.trim();
                    if (val.length >= 8) await _searchReceipt(df, val);
                  },
                ),
              ),
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 600), () async {
                  if (val.length >= 9) await _searchReceipt(df, val);
                });
              },
              onSubmitted: (val) async {
                if (val.length >= 8) await _searchReceipt(df, val);
              },
            ),

            const SizedBox(height: 16),

            // ── LOADING
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.blue,
                  ),
                ),
              ),

            // ── ERROR
            if (_searcherror != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Text(
                  _searcherror!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),

            // ── ITEMS LIST
            if (_receiptItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                "Items on Receipt (${_receiptItems.length})",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2635),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.15)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _receiptItems.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, i) {
                    final item = _receiptItems[i];
                    final double qty = double.tryParse(
                        item['returned_quantity']?.toString() ?? '0') ??
                        0;
                    final double price = double.tryParse(
                        item['returned_price']?.toString() ?? '0') ??
                        0;
                    final String total = (qty * price).toStringAsFixed(2);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      title: Text(
                        item['returned_item']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${item['returned_mode']} • Qty: ${qty.toStringAsFixed(0)} • GHC $total',
                        style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      leading: const Icon(Icons.inventory_2_outlined,
                          color: Colors.blue, size: 20),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── REASON DROPDOWN
              const Text(
                "Return Reason",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _buildConditionDropdown(df),

              const SizedBox(height: 24),

              // ── RETURN ALL BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.assignment_return, color: Colors.white),
                  label: const Text(
                    "Return All to Cart",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () => _addAllToCart(df),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildConditionDropdown(Datafeed df) {
    final reasons = df.returnitemreasons;
    if (reasons.isEmpty) return const SizedBox.shrink();

    _selectedConditionId ??= reasons.first.id;

    final exists = reasons.any((r) => r.id == _selectedConditionId);
    if (!exists) _selectedConditionId = reasons.first.id;

    return DropdownButtonFormField<String>(
      value: _selectedConditionId,
      dropdownColor: const Color(0xFF1A2635),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      iconEnabledColor: Colors.white70,
      decoration: _fieldInput("Select Reason", Icons.check_circle),
      items: reasons
          .map((c) => DropdownMenuItem<String>(
        value: c.id,
        child: Text(c.name,
            style: const TextStyle(color: Colors.white)),
      ))
          .toList(),
      onChanged: (v) => setState(() => _selectedConditionId = v),
    );
  }


  Widget _buildCartList(Datafeed df) {
    if (_cartItems.isEmpty) {
      return Card(
        color: const Color(0xFF131F2C),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.assignment_return_outlined,
                    size: 56, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  "Return cart is empty",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cartKeys = _cartItems.keys.toList();

    return Card(
      color: const Color(0xFF131F2C),
      elevation: 4,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row with title + Remove All button ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Return Cart (${_cartItems.length})",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      // Call your existing _removeFromCart logic for each key,
                      // or simply clear the map directly if that's sufficient
                      for (final key in cartKeys) {
                        _removeFromCart(key, df);
                      }
                    });
                  },
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent, size: 18),
                  label: const Text(
                    "Remove All",
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: Colors.redAccent.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: Colors.redAccent.withOpacity(0.3), width: 1),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 20, color: Colors.white10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final key = cartKeys[i];
                final item = _cartItems[key]!;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2635),
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  padding: const EdgeInsets.all(12),
                  // ── No delete button per row anymore ──
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['returned_item']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['returned_condition']} • Qty: ${item['returned_quantity']} • GHC ${item['returned_totalamount']}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSummaryCard() {
    if (_cartItems.isEmpty) return const SizedBox.shrink();

    final totalAmount = _cartItems.values.fold<double>(
      0.0,
          (sum, item) =>
      sum + (double.tryParse(item['returned_totalamount'].toString()) ?? 0),
    );

    return Card(
      color: Colors.blue.withOpacity(0.08),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow("Items Count", "${_cartItems.length}"),
            const Divider(color: Colors.white10, height: 20),
            _summaryRow(
              "Total Return Amount",
              "GHC ${totalAmount.toStringAsFixed(2)}",
              large: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white70,
                fontSize: large ? 14 : 13,
                fontWeight:
                large ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontSize: large ? 18 : 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }



  Widget _buildSaveButton(Datafeed df) {
    if (_cartItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          elevation: 4,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isLoading ? null : () => _saveReturn(df),
        child: _isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Colors.white),
        )
            : const Text(
          "Save Return",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
      ),
    );
  }


  InputDecoration _fieldInput(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: const Color(0xFF0E1A22),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
        BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
        BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }
}