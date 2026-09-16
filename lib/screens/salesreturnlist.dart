
import 'package:flutter/material.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/screens/salesreturn.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

import '../widgets/datepicker.dart';
import '../widgets/salesreturnpdf.dart';


class SalesreturnListPage extends StatefulWidget {
  const SalesreturnListPage({super.key});

  @override
  State<SalesreturnListPage> createState() => _SalesreturnListPageState();
}

class _SalesreturnListPageState extends State<SalesreturnListPage> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  @override
  void initState() {
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesreturn();
    });

  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {

        final filteredSalesreturn = value.filtersalesreturn();

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(title: const Text('Sales return List'),
            actions: [
              ReusableDatePickerWidget(
                child: const Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() => selectedDate = selection);
                  context.read<Datafeed>().fetchsalesreturn(
                    selectedDate: selectedDate,
                    selectedBranch: _selectedBranch,
                  );
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const Salesreturn()),
              );
            },
          ),
          body: value.isloadingsalesreturn
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                            value: _selectedBranch,
                            dropdownColor: const Color(0xFF22304A),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: 'Branch',
                              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFF1B263B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF415A77)),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('All Branches')),
                              ...{for (final b in value.branches) b.id: b}.values
                                  .where((b) => b.id != null && b.id!.isNotEmpty)
                                  .map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.branchname))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedBranch = val);
                              context.read<Datafeed>().fetchsalesreturn(
                                selectedDate: selectedDate,
                                selectedBranch: val,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            onChanged: value.updateSearch,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Search ...',
                              hintStyle: TextStyle(color: Colors.white54),
                              prefixIcon: Icon(Icons.search, color: Colors.white54),
                              filled: true,
                              fillColor: Color(0xFF22304A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: value.salesreturn.isEmpty
                          ? const Center(
                        child: Text(
                          'No Sales return found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : filteredSalesreturn.isEmpty
                          ? const Center(
                        child: Text(
                          'No Sales return found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filteredSalesreturn.length,
                        separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final salesreturn = filteredSalesreturn[index];

                          final id = salesreturn.id;
                          final Map<String, dynamic> itemMap =
                          Map<String, dynamic>.from(salesreturn.items ?? {});

                          final firstItem = itemMap.values.isNotEmpty &&
                              itemMap.values.first is Map<String, dynamic>
                              ? itemMap.values.first as Map<String, dynamic>
                              : {};

                          final itemName = firstItem['returned_item']?.toString() ?? '';

                          final receipt = firstItem['returned_receiptid']?.toString() ??  '';
                          final Trxdate = salesreturn.dateymd?.toString() ?? '';
                         final totalamountt = itemMap.values.fold<double>( 0, (sum, item) {
                            if (item is Map<String, dynamic>) {
                              final amount = double.tryParse(
                                  item['returned_totalamount']?.toString() ?? '0') ?? 0;
                              return sum + amount;
                            }
                            return sum;
                          },);

                          return Container(
                            margin: const EdgeInsets.symmetric(
                             vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B263B),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.05)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    color: Colors.white.withOpacity(0.03),
                                    child: Wrap(
                                      spacing: 10,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amberAccent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                                8),
                                          ),
                                          child: Text(
                                            "Receipt #$receipt",
                                            style: const TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ),

                                        Text(
                                          "#: ${index + 1}",
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                  0.5), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [

                                        ...itemMap.values.map((item) {
                                          if (item is! Map<String, dynamic>) {
                                            return const SizedBox();
                                          }
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.black12,
                                              borderRadius: BorderRadius
                                                  .circular(12),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment
                                                  .start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment
                                                      .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['returned_item']
                                                            ?.toUpperCase() ??
                                                            '',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight
                                                              .w800,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      "GHC ${item['returned_totalamount']}",
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Divider(color: Colors
                                                    .white10, height: 20),

                                                Table(
                                                  columnWidths: const {
                                                    0: FlexColumnWidth(1),
                                                    1: FlexColumnWidth(1),
                                                  },
                                                  children: [
                                                    _buildTableRow("Qty", "${item['returned_quantity']} (${item['returned_mode']})"),
                                                    _buildTableRow("Price",   "GHC ${item['returned_price']}"),
                                                    _buildTableRow("Discount",   "GHC ${item['returned_discount']}"),
                                                    _buildTableRow("Profit",   "GHC ${item['returned_profit']}"),
                                                    if(item['cp'] != null)
                                                      _buildTableRow("Cost Price ", "GHC ${item['returned_cp']}"),
                                                    if(item['returned_barcode'] != null)
                                                      _buildTableRow("Barcode", "${item['returned_barcode']}"),
                                                  ],
                                                ),

                                                if (item['returned_reason'] != null) ...[
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.redAccent.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      "Description: ${item['returned_reason']}",
                                                      style: const TextStyle(
                                                          color: Colors.redAccent,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }),

                                        const Divider(color: Colors.white24),


                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFooterLabel(
                                             Icons.person_outline,
                                             "Staff: ${salesreturn.createdby}"),
                                            const SizedBox(height: 4),
                                            _buildFooterLabel(
                                              Icons.calendar_today_outlined,
                                              "Entry Date: ${salesreturn.createdat
                                              .toDate().toLocal().toString().split(' ')[0]}",
                                            ),
                                            _buildFooterLabel(
                                              Icons.calendar_today_outlined,
                                              "Trnx: ${salesreturn.dateymd}",
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text("TOTAL AMOUNT",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 10)),
                                            Text(
                                              "GHC ${totalamountt.toString()}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),


                                  Container(
                                    color: Colors.black26,
                                    padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildActionButton(
                                          Icons.print, "Print",
                                          Colors.tealAccent, () async {
                                          try {
                                            final Map<String, dynamic> itemsMap =
                                            Map<String, dynamic>.from(salesreturn.items);

                                            // Remap returned
                                            final Map<String, dynamic> remappedItems = {};
                                            itemsMap.forEach((key, value) {
                                              if (value is Map<String, dynamic>) {
                                                final remapped = <String, dynamic>{};
                                                value.forEach((k, v) {
                                                  final plainKey = k.startsWith('returned_')
                                                      ? k.replaceFirst('returned_', '')
                                                      : k;
                                                  remapped[plainKey] = v;
                                                });
                                                remappedItems[key] = remapped;
                                              }
                                            });

                                            await SalesReturnPdf.generate(
                                              header: {
                                                'company': salesreturn.companyid,
                                                'branchname': salesreturn.branchname,
                                                'createdby': salesreturn.createdby,
                                                'createdat': salesreturn.createdat,
                                                'receiptid': firstItem['returned_receiptid'] ?? '',
                                                'transmode': firstItem['returned_transMode'] ?? '',
                                              },
                                              itemsMap: remappedItems,
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Failed to generate PDF: $e"),
                                                backgroundColor: Colors.redAccent,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        ),

                                        if(value.canDelete(AppModules.sales))
                                        _buildActionButton(
                                          Icons.delete_outline, "Delete",
                                          Colors.redAccent, () =>
                                            _handleDelete(context, itemName, id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
  Future<void> _handleDelete(BuildContext context, String itemName, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
            "Delete $itemName?",
            style: const TextStyle(color: Colors.white)
        ),
        content: Text(
          "This action cannot be undone. Are you sure?",
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Accessing the provider
        await context.read<Datafeed>().deletesalesreturn(id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$itemName deleted successfully",style: const TextStyle(color: Colors.white),),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete item"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}






