

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import 'closesales.dart';


class CloseSalesViewPage extends StatefulWidget {
  const CloseSalesViewPage({super.key});

  @override
  State<CloseSalesViewPage> createState() => _CloseSalesViewPageState();
}

class _CloseSalesViewPageState extends State<CloseSalesViewPage> {
  String searchQuery = '';
  DateTime? selectedDate;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  void _sort<T>(
      Comparable<T> Function(dynamic d) getField,
      int columnIndex,
      bool ascending,
      List list,
      ) {
    list.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);

      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }
  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
  Future<void> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });

      context.read<Datafeed>().fetchcloseSales(picked);
    }
  }
  @override
  void initState() {
    super.initState();
    Future.microtask((){

      context.read<Datafeed>().fetchcloseSales();
    });

  }
  void _showDetailsDialog(BuildContext context, Map<String, dynamic> salesview) {
    final staff = salesview['staff'] ?? '';
    final total = salesview['total'] ?? 0;
    final createdAt = salesview['createdAt'] as Timestamp?;
    final money = salesview['money'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B263B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Close Sale Details",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFooterLabel(Icons.person_outline, "Staff: $staff"),
                      _buildFooterLabel(
                        Icons.calendar_today_outlined,
                        "Date: ${createdAt != null ? DateFormat.yMMMd().format(createdAt.toDate()) : ''}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  ...money.map((denom) {
                    if (denom is Map<String, dynamic>) {
                      final denomination = denom['denomination'] ?? 0;
                      final quantity = denom['quantity'] ?? 0;
                      final denomTotal = denom['total'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("GHC $denomination x $quantity", style: const TextStyle(color: Colors.white)),
                            Text("GHC $denomTotal", style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  }),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "GHC $total",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredSalesview = value.closesales;
        print(filteredSalesview);
        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text('Close Sales View List'),
            actions: [
              ElevatedButton(
                onPressed: () => pickDate(context),
                child: const Text("Select Date",style: TextStyle(color: Colors.white),),
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CloseSalesPage()),
              );
            },
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    const SizedBox(height: 3),
                    if (selectedDate != null)...[
                      const Text('Close Sales View List for the period of:'),
                      Text(
                        "${DateFormat.yMMMd().format(selectedDate!)} ",
                        style: const TextStyle(fontSize: 12,color: Colors.white),
                      ),
                    ],

                    Expanded(
                      child: value.isloadingclosesale
                          ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                          : value.closesales.isEmpty
                          ? const Center(
                        child: Text(
                          'No Close Sales found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 500;

                          if (isDesktop) {
                            // Apply current sort before building rows
                            if (_sortColumnIndex != null) {
                              switch (_sortColumnIndex) {
                                case 1:
                                  filteredSalesview.sort((a, b) {
                                    final cmp = (a['staff'] ?? '').toString().compareTo((b['staff'] ?? '').toString());
                                    return _sortAscending ? cmp : -cmp;
                                  });
                                  break;
                                case 2:
                                  filteredSalesview.sort((a, b) {
                                    final da = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
                                    final db = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1900);
                                    final cmp = da.compareTo(db);
                                    return _sortAscending ? cmp : -cmp;
                                  });
                                  break;
                                case 3:
                                  filteredSalesview.sort((a, b) {
                                    final ta = (a['total'] ?? 0) as num;
                                    final tb = (b['total'] ?? 0) as num;
                                    final cmp = ta.compareTo(tb);
                                    return _sortAscending ? cmp : -cmp;
                                  });
                                  break;
                              }
                            }

                            const columnWidths = <double>[40, 150, 130, 110, 200];
                            const columnLabels = <String>['#', 'Staff', 'Date', 'Total', 'Action'];

                            Widget buildHeaderLabel(int index) {
                              final sortable = index == 1 || index == 2 || index == 3;
                              final isActive = _sortColumnIndex == index;
                              final label = Text(
                                columnLabels[index],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              );

                              Widget content = label;
                              if (sortable) {
                                content = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    label,
                                    if (isActive) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                    ],
                                  ],
                                );
                              }

                              return SizedBox(
                                width: columnWidths[index],
                                child: sortable
                                    ? InkWell(
                                  onTap: () => setState(() {
                                    if (_sortColumnIndex == index) {
                                      _sortAscending = !_sortAscending;
                                    } else {
                                      _sortColumnIndex = index;
                                      _sortAscending = true;
                                    }
                                  }),
                                  child: Align(alignment: Alignment.centerLeft, child: content),
                                )
                                    : Align(alignment: Alignment.centerLeft, child: content),
                              );
                            }

                            List<Widget> withSpacing(List<Widget> cells) {
                              final spaced = <Widget>[];
                              for (var i = 0; i < cells.length; i++) {
                                spaced.add(cells[i]);
                                if (i != cells.length - 1) spaced.add(const SizedBox(width: 10));
                              }
                              return spaced;
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

                                thumbVisibility: true,
                                trackVisibility: true,
                                interactive: true,
                                notificationPredicate: (notif) => notif.depth == 1,
                                child: SingleChildScrollView(

                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 700,
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(horizontal: 15),
                                          color: const Color(0xFF22304A),
                                          child: Row(
                                            children: withSpacing(
                                              List.generate(columnLabels.length, buildHeaderLabel),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: filteredSalesview.length,
                                            itemBuilder: (context, index) {
                                              final salesview = filteredSalesview[index];
                                              final id = salesview['id'] ?? '';
                                              final staff = salesview['staff'] ?? '';
                                              final total = salesview['total'] ?? 0;
                                              final createdAt = salesview['createdAt'] as Timestamp?;
                                              final money = salesview['money'] ?? [];

                                              final cells = <Widget>[
                                                Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
                                                Text(staff, style: const TextStyle(color: Colors.white)),
                                                Text(
                                                  createdAt != null ? DateFormat.yMMMd().format(createdAt.toDate()) : '',
                                                  style: const TextStyle(color: Colors.white),
                                                ),
                                                Text('GHC $total', style: const TextStyle(color: Colors.white)),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_red_eye, color: Colors.amberAccent, size: 18),
                                                      onPressed: () => _showDetailsDialog(context, salesview),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
                                                      onPressed: () {
                                                        _handleEdit(
                                                          context,
                                                          id,
                                                          (money as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                                                        );
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                                      onPressed: () => _handleDelete(context, staff, id),
                                                    ),
                                                  ],
                                                ),
                                              ];

                                              return InkWell(
                                                onTap: () => _showDetailsDialog(context, salesview),
                                                child: Container(
                                                  height: 52,
                                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                                  color: const Color(0xFF1B263B),
                                                  child: Row(
                                                    children: withSpacing(
                                                      List.generate(columnWidths.length, (i) {
                                                        return SizedBox(
                                                          width: columnWidths[i],
                                                          child: Align(alignment: Alignment.centerLeft, child: cells[i]),
                                                        );
                                                      }),
                                                    ),
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
                          }
                          /// MOBILE
                          return ListView.separated(
                            itemCount: filteredSalesview.length,
                            separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final salesview = filteredSalesview[index];

                              final id = salesview['id'] ?? '';
                              final staff = salesview['staff'] ?? '';
                              final total = salesview['total'] ?? 0;
                              final createdAt = salesview['createdAt'] as Timestamp?;
                              final money = salesview['money'] as List<dynamic>? ?? [];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B263B),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all( color: Colors.white.withOpacity(0.05)),
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
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.amberAccent.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular( 8),),
                                              child: Text(
                                                "Staff: $staff",
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text("#: ${index + 1}",
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity( 0.5),
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [

                                            ...money.map((denom) {
                                              if (denom is Map<String, dynamic>) {
                                                final denomination = denom['denomination'] ?? 0;
                                                final quantity = denom['quantity'] ?? 0;
                                                final denomTotal = denom['total'] ?? 0;
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black12,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text("GHC $denomination x $quantity", style: const TextStyle(color: Colors.white)),
                                                      Text("GHC $denomTotal", style: const TextStyle(color: Colors.white70)),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return const SizedBox();
                                            }),

                                            const Divider(color: Colors.white24),


                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildFooterLabel(
                                                        Icons.person_outline,
                                                        "Staff: $staff"),
                                                    const SizedBox(height: 4),
                                                    _buildFooterLabel(
                                                      Icons.calendar_today_outlined,
                                                      "Date: ${createdAt != null ? DateFormat.yMMMd().format(createdAt.toDate()) : ''}",
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
                                                      "GHC $total",
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
                                          ],
                                        ),
                                      ),


                                      Container(
                                        color: Colors.black26,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildActionButton(
                                              Icons.edit, "Edit",
                                              Colors.blueAccent,
                                                  () {
                                                _handleEdit( context,
                                                  id,
                                                  (money as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              Icons.delete_outline, "Delete",
                                              Colors.redAccent, () =>
                                                _handleDelete(context, staff, id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                            },

                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
  Future<void> _handleDelete(BuildContext context, String staff, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
            "Delete close sale by $staff?",
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
        await context.read<Datafeed>().deleteCloseSale(id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$staff's close sale deleted successfully"),
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
  Future<void> _handleEdit( BuildContext context, String id, List<Map<String, dynamic>> item, ) async {
    Navigator.push( context,
      MaterialPageRoute(
        builder: (context) => CloseSalesPage(
          docId: id,
          item: item,
        ),
      ),
    );
  }

}

class SalesDataSource extends DataTableSource {
  final List<Map<String, dynamic>> sales;
  final BuildContext context;
  final Function sort;
  final Function handleDelete;
  final Function handleEdit;

  SalesDataSource({
    required this.sales,
    required this.context,
    required this.sort,
    required this.handleDelete,
    required this.handleEdit,
  });

  @override
  DataRow getRow(int index) {
    final salesview = sales[index];

    final id = salesview['id'] ?? '';
    final staff = salesview['staff'] ?? '';
    final total = salesview['total'] ?? 0;
    final createdAt = salesview['createdAt'] as Timestamp?;
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text("${index + 1}")),
        DataCell(Text(staff)),
        DataCell(Text(createdAt != null ? DateFormat.yMMMd().format(createdAt.toDate()) : '')),
        DataCell(Text("GHC $total")),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () {
                  final money = salesview['money'] ?? [];
                  handleEdit(
                    context,
                    id,
                    (money as List)
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => handleDelete(context, staff, id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => sales.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}