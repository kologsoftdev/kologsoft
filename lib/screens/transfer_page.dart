import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/transferinvoice.dart';
import 'package:kologsoft/screens/transfers.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../models/appModuls.dart';
import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';

class StockTransferDetailsList extends StatefulWidget {
  StockTransferDetailsList ({super. key});
  @override
  State<StockTransferDetailsList> createState() => _StockTransferDetailsListState();
}

class _StockTransferDetailsListState extends State<StockTransferDetailsList> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";
  bool _isDateRangeActive=false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.microtask(() async{
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.getdata();
    });
  }
  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF22304A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _endDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Color(0xFF22304A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (end != null) {
        setState(() {
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          _isDateRangeActive = true;
        });
        if (_startDate == null || _endDate == null) return;

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider= Provider.of<StockProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B263B),
          elevation: 0,
          title: const Text("Stock Transfer",
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isDateRangeActive
                      ? Colors.blue.shade800.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: _isDateRangeActive ? Colors.blue.shade300 : Colors.white70,
                ),
              ),
              onPressed: _showDateRangePicker,
              tooltip: 'Filter by date range',
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF415A77),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewTransfer()),
          );
        },
      ),

      body:  Center(
    child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 800),
     child:  ListView(
        children: [

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              child: TextFormField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  fillColor: Color(0xFF22304A),
                  hintText: 'Search  ...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: searchQuery.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        searchQuery = "";
                      });
                    },
                  ) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: provider.stockStream(collectionName: 'stock_transfer',branchfield: 'staffbranchid',startDate: _startDate, endDate: _endDate, datefield: 'transferdate'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Text(
                    "No items",
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              final allDocs = snapshot.data!;
              final filteredDocs = allDocs.where((doc) {
                final data = doc as Map<String, dynamic>;
                return data.values.any((value) {
                  if (value == null) return false;
                  return value.toString().toLowerCase().contains(searchQuery);
                });
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Text(
                    searchQuery.isEmpty
                        ? "No items transferred"
                        : "No items found matching '$searchQuery'",
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc as Map<String, dynamic>;
                  final rawItems = data['items'];

                  List<Map<String, dynamic>> items = [];
                  final value= Provider.of<Datafeed>(context, listen: false);

                  if (rawItems is List) {
                    items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
                  } else if (rawItems is Map) {
                    items = rawItems.entries.map((entry) {
                      return {
                        'key': entry.key,
                        ...Map<String, dynamic>.from(entry.value),
                      };
                    }).toList();
                  }
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${data['supplywarehousename']}" " - " "${data['recievebranchname']}",
                              style: const TextStyle(color: Colors.amberAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),

                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF415A77),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...items.map((item) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.label, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${item['item']}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              Text("Qty: ${item['quantity']}", style: const TextStyle(color: Colors.white)),
                              Text("Mode: ${item['transfermode']}", style: const TextStyle(color: Colors.white)),
                              Text("Purchase price: ${item['price']}", style: const TextStyle(color: Colors.white)),
                              Text("Total: ${item['total']}", style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 6),
                              const Divider(color: Colors.white24, height: 20),

                            ],
                          );
                        }).toList(),

                        Text(
                          "Date: ${data['createdat'].toDate().toString().substring(0, 10)}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          "Staff: ${data['createdby'].toString()}",
                          style: const TextStyle(color: Colors.white),
                        ),

                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Amount: GHC ${data['gross'].toStringAsFixed(2) ?? 0}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print_outlined, color: Colors.tealAccent),
                                  onPressed: () async {
                                    try {
                                      await generateInvoicePdf(data, items);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Error generating PDF: $e"), backgroundColor: Colors.red),
                                      );
                                    }
                                  },
                                ),

                                if (data['status']?.toLowerCase() == 'pending') ...[
                                  if(value.canEdit(AppModules.stock))
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => NewTransfer(
                                              docId: data['docid'],
                                              data: data,
                                            ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Edit',
                                    ),
                                  if(value.canDelete(AppModules.stock))
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor: const Color(0xFF1B263B),
                                            title: const Text(
                                              "Delete Transfer Invoice",
                                              style: TextStyle(color: Colors.white),
                                            ),
                                            content: const Text(
                                              "Are you sure you want to delete this transfer invoice?",
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text(
                                                  "Cancel",
                                                  style: TextStyle(color: Colors.white54),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                                child: const Text("Delete"),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          LoadingDialog.show(
                                            context,
                                            message: "Please wait...",
                                          );

                                          try {
                                            final stockProvider = context.read<StockProvider>();
                                            final insufficientItems = <String>[];

                                            for (final item in items) {
                                              final itemId = (item['itemid'] ?? '').toString();
                                              final itemName = (item['item'] ?? '').toString();

                                              final piecesToReverse =
                                                  (item['pieces'] as num?)?.toDouble() ?? 0;

                                              final availableBalance =
                                              await stockProvider.fetchItemCurrentBalance(
                                                itemId: itemId,
                                                selectedBranch: data['recievebranchid'],
                                              );

                                              if (availableBalance < piecesToReverse) {
                                                insufficientItems.add(
                                                  '$itemName\n'
                                                      'Available: ${availableBalance.toInt()} pcs\n'
                                                      'Required: ${piecesToReverse.toInt()} pcs',
                                                );
                                              }
                                            }

                                            if (insufficientItems.isNotEmpty) {
                                              if (!context.mounted) return;

                                              await showDialog(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text("Cannot Delete Transfer"),
                                                  content: SingleChildScrollView(
                                                    child: Text(
                                                      "The following items no longer have enough stock in "
                                                          "${data['recievebranchname']} to reverse this transfer:\n\n"
                                                          "${insufficientItems.join('\n\n')}",
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text(
                                                        "OK",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              return;
                                            }

                                            await db.collection('stock_transfer').doc(data['docid']).delete();

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("Stock transfer deleted successfully"),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("Failed to delete transfer: $e"),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (context.mounted) {
                                              LoadingDialog.hide();
                                            }
                                          }
                                        }
                                      },
                                      tooltip: 'Delete',
                                    ),
                                ]
                              ],
                            ),
                          ],
                        ),

                      ],
                    ),
                  );

                },
              );

            },
          ),
        ],
      ),
    )));
  }
}
