

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/damageitem.dart';
import '../providers/Datafeed.dart';
import '../utils/damagepdf.dart';
import '../widgets/datepicker.dart';
import 'damages.dart';

class DamagesListPage extends StatefulWidget {
  const DamagesListPage({super.key});

  @override
  State<DamagesListPage> createState() => _DamagesListPageState();
}

class _DamagesListPageState extends State<DamagesListPage> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final verticalController = ScrollController();
  final horizontalController = ScrollController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchdamages(selectedDate: selectedDate);
    });
    selectedDate = null;
  }

  List<damageitemmodel> filterdamages(Datafeed value) {
    if (searchQuery.isEmpty) return value.damages;
    final q = searchQuery.toLowerCase();
    return value.damages.where((s) {
      final Map<String, dynamic> itemMap = Map<String, dynamic>.from(s?.item ?? {});
      return itemMap.values.any((item) {
        if (item is Map<String, dynamic>) {
          return [
            item['item'], item['itemid'], item['mode'], item['reason'],
            item['cp'], item['barcode'], item['modeqty'], item['quantity'],
            item['totalpieces'],
          ].any((v) => v?.toString().toLowerCase().contains(q) ?? false);
        }
        return false;
      });
    }).toList();
  }

  double _calcTotal(Map<String, dynamic> itemMap) {
    return itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
        final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
        return sum + (cp * qty);
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1050;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredDamages = filterdamages(value);

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text('Damages List'),
            actions: [
              ReusableDatePickerWidget(
                child: const Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() => selectedDate = selection);
                  context.read<Datafeed>().fetchdamages(selectedDate: selection);
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Damages()),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 800,
                ),
                child: Column(
                  children: [

                    TextFormField(
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search Damages...',
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
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredDamages.isEmpty
                          ? const Center(
                        child: Text('No Damages found',
                            style: TextStyle(color: Colors.white70)),
                      )
                          : isDesktop
                          ? _desktopTable(filteredDamages,value)
                          : _mobileList(filteredDamages,value),
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

  // DESKTOP TABLE

  Widget _desktopTable(List<damageitemmodel> items,Datafeed value) {
    final source = _DamageDataSource(
      items: items,
      context: context,
      calcTotal: _calcTotal,
      onEdit: (d) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Damages(damageitem: d)),
      ),
      onDelete: (d) {
        final itemMap = Map<String, dynamic>.from(d?.item ?? {});
        final firstItem = itemMap.values.isNotEmpty && itemMap.values.first is Map
            ? itemMap.values.first as Map<String, dynamic>
            : {};

        _handleDelete(context, firstItem['item']?.toString() ?? '', d.id);
      },
      onPrint: (d) async {
        final itemsMap = Map<String, dynamic>.from(d?.item ?? {});
        await DamageReportPdf.generate(
          header: {
            'company': d.company,
            'branchname': d.branchname,
            'createdby': d.createdby,
            'createdat': d.createdat,
          },
          itemsMap: itemsMap,
        );
      },
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      value: value,
    );

    const columnWidths = <double>[30, 250, 140, 90, 90, 250];
    const columnLabels = <String>['#', 'Item', 'Total (GHS)', 'Date', 'Trx Date', 'Actions'];

    Widget buildHeaderLabel(int index) {
      final sortable = index == 1 || index == 2;
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
          mainAxisAlignment:
          index == 2 ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (index == 2 && isActive) ...[
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            label,
            if (index != 2 && isActive) ...[
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

      final aligned = Align(
        alignment: index == 2 ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      );

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
          child: aligned,
        )
            : aligned,
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
        thumbColor: MaterialStateProperty.all(
          const Color(0xFF415A77),
        ),
        trackColor: MaterialStateProperty.all(
          const Color(0xFF22304A),
        ),
        trackBorderColor: MaterialStateProperty.all(
          const Color(0xFF1B263B),
        ),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1050,
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
                  child: Scrollbar(
                    controller: verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: ListView.builder(
                      controller: verticalController,
                      itemCount: source.rowCount,
                      itemBuilder: (context, index) {
                        final cells = source.getRow(index);
                        if (cells == null) return const SizedBox();
                        return Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          color: const Color(0xFF1B263B),
                          child: Row(
                            children: withSpacing(
                              List.generate(columnWidths.length, (i) {
                                return SizedBox(
                                  width: columnWidths[i],
                                  child: Align(
                                    alignment: i == 2
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: cells[i],
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
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

  //  MOBILE LIST

  Widget _mobileList(List<damageitemmodel> filteredDamages,Datafeed value) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.separated(
          itemCount: filteredDamages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final damages = filteredDamages[index];
            final id = damages.id;

            final Map<String, dynamic> itemMap =
            Map<String, dynamic>.from(damages?.item ?? {});
            final firstItem = itemMap.values.isNotEmpty &&
                itemMap.values.first is Map<String, dynamic>
                ? itemMap.values.first as Map<String, dynamic>
                : {};
            final itemName = firstItem['item']?.toString() ?? '';
            final totalamountt = _calcTotal(itemMap);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                    // ── header ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white.withOpacity(0.03),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "ITEM #$itemName",
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "#: ${index + 1}",
                            softWrap: true,
                            maxLines: 2,
                            style: TextStyle(
                                color: Colors.white70.withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // ── items ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...itemMap.values.map((item) {
                            if (item is! Map<String, dynamic>) return const SizedBox();
                            final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
                            final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
                            final itemCost = cp * qty;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['item']?.toUpperCase() ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "GHC ${itemCost.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 20),
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1),
                                      1: FlexColumnWidth(1),
                                    },
                                    children: [
                                      _buildTableRow("Qty", "${item['quantity']} (${item['mode']})"),
                                      if (item['cp'] != null) ...[
                                        _buildTableRow("CP", "GHC ${cp.toStringAsFixed(2)}"),
                                        _buildTableRow("Mode qty", "${item['modeqty']}"),
                                      ],
                                      if (item['barcode'] != null)
                                        _buildTableRow("Barcode", "${item['barcode']}"),
                                    ],
                                  ),
                                  if (item['reason'] != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Description: ${item['reason']}",
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFooterLabel(Icons.person_outline,
                                      "Staff: ${damages.createdby}"),
                                  const SizedBox(height: 4),
                                  _buildFooterLabel(
                                      Icons.calendar_today_outlined,
                                      "Date: ${damages.createdat.toString().substring(0, 10)}"),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("TOTAL AMOUNT",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 10)),
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
                        ],
                      ),
                    ),

                    // ── actions ──
                    Container(
                      color: Colors.black26,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
                      //  mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(Icons.print, "Print",
                              Colors.tealAccent, () async {
                                final itemsMap =
                                Map<String, dynamic>.from(damages?.item ?? {});
                                await DamageReportPdf.generate(
                                  header: {
                                    'company': damages.company,
                                    'branchname': damages.branchname,
                                    'createdby': damages.createdby,
                                    'createdat': damages.createdat,
                                  },
                                  itemsMap: itemsMap,
                                );
                              }),
                          Visibility(
                            visible: value.canEdit(AppModules.stock),
                            child: _buildActionButton(Icons.edit_outlined, "",   Colors.amber, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => Damages(damageitem: damages)),
                              );
                            }),
                          ),
                          Visibility(
                              visible: value.canDelete(AppModules.stock),
                              child: _buildActionButton(Icons.delete_outline, "",   Colors.redAccent,
                                      () => _handleDelete(context, itemName, id))),

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
    );
  }

  // HELPERS

  TableRow _buildTableRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: Colors.white54, size: 14),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]);
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  Future<void> _handleDelete(
      BuildContext context, String itemName, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text("Delete $itemName?",
            style: const TextStyle(color: Colors.white)),
        content: Text("This action cannot be undone. Are you sure?",
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child:
            const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child:
            const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<Datafeed>().deletedamage(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$itemName deleted successfully",style: TextStyle(color: Colors.white),),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to delete item",style: TextStyle(color: Colors.white),),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }
}

// DATA SOURCE

class _DamageDataSource {
  List<damageitemmodel> items;
  final BuildContext context;
  final double Function(Map<String, dynamic>) calcTotal;
  final void Function(damageitemmodel) onEdit;
  final void Function(damageitemmodel) onDelete;
  final Future<void> Function(damageitemmodel) onPrint;
  Datafeed value;
  _DamageDataSource({
    required this.items,
    required this.context,
    required this.calcTotal,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.value,
    int sortColumnIndex = 0,
    bool sortAscending = true,
  }) {
    _sort(sortColumnIndex, sortAscending);
  }

  void _sort(int columnIndex, bool ascending) {
    items.sort((a, b) {
      int result = 0;
      final aMap = Map<String, dynamic>.from(a?.item ?? {});
      final bMap = Map<String, dynamic>.from(b?.item ?? {});
      final aFirst = aMap.values.isNotEmpty && aMap.values.first is Map
          ? aMap.values.first as Map<String, dynamic>
          : {};
      final bFirst = bMap.values.isNotEmpty && bMap.values.first is Map
          ? bMap.values.first as Map<String, dynamic>
          : {};

      switch (columnIndex) {
        case 1: // Item name
          result = (aFirst['item']?.toString() ?? '')
              .compareTo(bFirst['item']?.toString() ?? '');
          break;
        case 4: // Total
          result = calcTotal(aMap).compareTo(calcTotal(bMap));
          break;
      }
      return ascending ? result : -result;
    });
  }

  List<Widget>? getRow(int index) {
    if (index >= items.length) return null;
    final d = items[index];
    final itemMap = Map<String, dynamic>.from(d?.item ?? {});
    final firstItem = itemMap.values.isNotEmpty && itemMap.values.first is Map
        ? itemMap.values.first as Map<String, dynamic>
        : {};
    final itemName = firstItem['item']?.toString() ?? '';
    final total = calcTotal(itemMap);
    final itemCount = itemMap.length;

    return [
      Text('${index + 1}',
          style: const TextStyle(color: Colors.white70)),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        Text( itemName.toUpperCase(),
         maxLines: 1,
         overflow: TextOverflow.ellipsis,
         style: const TextStyle(
         color: Colors.white70, fontWeight: FontWeight.w700)),

          Text('$itemCount item(s)',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
      Text('GHC ${NumberFormat('#,##0.00').format(total)}',
          style: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold)),
      Text(d.createdat.toString().substring(0, 10),
          style: const TextStyle(color: Colors.white70)),
      Text(d.dateymd.toString().substring(0, 10),
          style: const TextStyle(color: Colors.white70)),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.tealAccent, size: 18),
            onPressed: () => onPrint(d),
            tooltip: 'Print',
          ),
          Visibility(
              visible: value.canEdit(AppModules.stock),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.amber, size: 18),
                onPressed: () => onEdit(d),
                tooltip: 'Edit',
              )),
          Visibility(
              visible: value.canDelete(AppModules.stock),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                onPressed: () => onDelete(d),
                tooltip: 'Delete',
              )),
        ],
      ),
    ];
  }

  int get rowCount => items.length;
}