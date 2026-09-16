import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../providers/Datafeed.dart';

class SupplyReportPage extends StatefulWidget {
  const SupplyReportPage({super.key});

  @override
  State<SupplyReportPage> createState() => _SupplyReportPageState();
}

class _SupplyReportPageState extends State<SupplyReportPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedBranchId;

  bool _loading = false;

  List<Map<String, dynamic>> _reportItems = [];
  List<Map<String, dynamic>> _cachedSales = [];
  bool _salesLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();

    _startDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    _endDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final datafeed = Provider.of<Datafeed>(context, listen: false,);
      datafeed.fetchBranches();
      _loadReport();
    });

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  List<Map<String, dynamic>> get _visibleReportItems {
    if (_searchQuery.isEmpty) return _reportItems;

    return _reportItems.where((item) {
      final searchable = [
        item['item'],
        item['itemid'],
        item['barcode'],
        item['branchname'],
        item['branchid'],
        item['status'],
      ].join(' ').toLowerCase();
      return searchable.contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDateRange() async {
    final initialStart = _startDate ?? DateTime.now();
    final initialEnd = _endDate ?? initialStart;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd.isBefore(initialStart)
            ? initialStart
            : initialEnd,
      ),
    );

    if (picked == null) return;

    setState(() {
      _startDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );

      _endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
    });

    await _loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport({bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final datafeed = Provider.of<Datafeed>(
        context,
        listen: false,
      );

      final bool isSuperAdmin =
          datafeed.accesslevel.toLowerCase().trim() == 'super admin';

      if (!_salesLoaded || refresh) {
        await datafeed.getdata();
        final companyId = datafeed.companyid;

        if (companyId.isEmpty) {
          throw 'Company information not found.';
        }

        final snapshot = await db
            .collection('sales')
            .where('companyId', isEqualTo: companyId)
            .orderBy('createdAt', descending: false)
            .get();

        _cachedSales = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['_documentId'] = doc.id;
          return data;
        }).toList();
        _salesLoaded = true;
      }

      final DateTime start = _startDate ??
          DateTime.now();

      final DateTime endExclusive = DateTime(
        (_endDate ?? start).year,
        (_endDate ?? start).month,
        (_endDate ?? start).day + 1,
      );

    // ==========================================================
    // AGGREGATE UNIQUE ITEM + BRANCH
    //
    // key = itemid + branchid
    // ==========================================================

    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final data in _cachedSales) {
    final createdAt = data['createdAt'];
    final saleDate = createdAt is Timestamp
      ? createdAt.toDate()
      : DateTime.tryParse(createdAt?.toString() ?? '');

    if (saleDate == null ||
      saleDate.isBefore(start) ||
      !saleDate.isBefore(endExclusive)) {
    continue;
    }

    final rawItems = data['items'];

    if (rawItems is! Map) {
    continue;
    }

    for (final entry in rawItems.entries) {
    final itemData = entry.value;

    if (itemData is! Map) {
    continue;
    }

    final item = Map<String, dynamic>.from(
    itemData,
    );

    final itemId =
    item['itemid']?.toString().trim() ?? '';

    if (itemId.isEmpty) {
    continue;
    }


    final branchId = item['branchid']?.toString().trim() ?? data['branchId']?.toString().trim() ?? '';

    final branchName = item['branchname']?.toString().trim() ?? data['branchName']?.toString().trim() ?? branchId;

    if (branchId.isEmpty) {
    continue;
    }

    if (!isSuperAdmin && branchId != datafeed.branchid) {
    continue;
    }

    if (isSuperAdmin &&
    _selectedBranchId != null &&
    _selectedBranchId!.isNotEmpty &&
    branchId != _selectedBranchId) {
    continue;
    }

    final key = '$itemId::$branchId';

    final quantity =
    double.tryParse(
    item['quantity']?.toString() ?? '0',
    ) ??
    0;

    final pieces =
    double.tryParse(
    item['totalpieces']?.toString() ??
    item['pieces']?.toString() ??
    '0',
    ) ??
    0;

    final rawSupplied = item['isSupplied'];
    final isSupplied = rawSupplied == true ||
    rawSupplied?.toString().toLowerCase() == 'true';

    // --------------------------------------------------------
    // CREATE FIRST RECORD
    // --------------------------------------------------------

    if (!aggregated.containsKey(key)) {
    aggregated[key] = {
    'itemid': itemId,
    'item': item['item']?.toString() ?? '',
    'barcode': item['barcode']?.toString() ?? '',
    'branchid': branchId,
    'branchname': branchName,

    'quantity': 0.0,
    'pieces': 0.0,
    'suppliedQuantity': 0.0,
    'pendingQuantity': 0.0,
    'suppliedPieces': 0.0,
    'pendingPieces': 0.0,

    // Track how many occurrences were supplied/pending.
    'suppliedCount': 0,
    'pendingCount': 0,

    // Latest status.
    'supplystatus': false,

    'transactionCount': 0,
    };
    }

    final current = aggregated[key]!;

    current['quantity'] =
    (current['quantity'] as double) + quantity;

    current['pieces'] =
    (current['pieces'] as double) + pieces;

    current['transactionCount'] =
    (current['transactionCount'] as int) + 1;

    if (isSupplied) {
    current['suppliedQuantity'] =
    (current['suppliedQuantity'] as double) + quantity;
    current['suppliedPieces'] =
    (current['suppliedPieces'] as double) + pieces;
    current['suppliedCount'] =
    (current['suppliedCount'] as int) + 1;
    } else {
    current['pendingQuantity'] =
    (current['pendingQuantity'] as double) + quantity;
    current['pendingPieces'] =
    (current['pendingPieces'] as double) + pieces;
    current['pendingCount'] =
    (current['pendingCount'] as int) + 1;
    }
    }
    }

    // ============================================================
    // DETERMINE FINAL STATUS FOR UNIQUE ITEM + BRANCH
    // ============================================================

    final List<Map<String, dynamic>> result = [];

    for (final item in aggregated.values) {
    final suppliedCount =
    item['suppliedCount'] as int;

    final pendingCount =
    item['pendingCount'] as int;

    String status;

    if (pendingCount == 0 && suppliedCount > 0) {
    status = 'approved';
    } else if (suppliedCount == 0) {
    status = 'pending';
    } else {
    status = 'partial';
    }

    item['status'] = status;

    result.add(item);
    }

    // Sort alphabetically
    result.sort(
    (a, b) => a['item']
        .toString()
        .toLowerCase()
        .compareTo(
    b['item']
        .toString()
        .toLowerCase(),
    ),
    );

    if (!mounted) return;

    setState(() {
    _reportItems = result;
    });
  } catch (e, stackTrace) {
  debugPrint(
  'Supply report error: $e',
  );

  debugPrint(
  stackTrace.toString(),
  );

  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
  content: Text(
  'Failed to load supply report: $e',
  ),
  backgroundColor: Colors.red,
  ),
  );
  }
} finally {
if (mounted) {
setState(() {
_loading = false;
});
}
}
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
  final datafeed = context.watch<Datafeed>();

  final bool isSuperAdmin =
      datafeed.accesslevel.toLowerCase().trim() ==
          'super admin';

  final partialCount = _reportItems
      .where((e) => e['status'] == 'partial')
      .length;
  final suppliedQuantity = _reportItems.fold<double>(
    0,
        (total, item) => total + (item['suppliedQuantity'] as double),
  );
  final pendingQuantity = _reportItems.fold<double>(
    0,
        (total, item) => total + (item['pendingQuantity'] as double),
  );
  final visibleItems = _visibleReportItems;

  return Scaffold(
    backgroundColor: Constants.bgDark,
    appBar: AppBar(
      title: const Text(
        'Supply Report',
        style: TextStyle(
          color: Constants.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Constants.bgCard,
      foregroundColor: Constants.textPrimary,
      actions: [
        IconButton(
          onPressed: _loading
              ? null
              : _loadReport,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        // ========================================================
        // FILTER BAR
        // ========================================================

        Container(
          padding: const EdgeInsets.all(16),
          color: Constants.bgCard,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateFilter = _filterButton(
                    icon: Icons.date_range,
                    title: 'Date',
                    value: _dateText(),
                    onTap: _selectDateRange,
                  );

                  if (!isSuperAdmin) return dateFilter;

                  final branchFilter = _branchDropdown(datafeed);
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        dateFilter,
                        const SizedBox(height: 10),
                        branchFilter,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: dateFilter),
                      const SizedBox(width: 12),
                      Expanded(child: branchFilter),
                    ],
                  );
                },
              ),

              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Constants.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search item, barcode, branch or status',
                  hintStyle: const TextStyle(color: Constants.textMuted),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Constants.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          color: Constants.textSecondary,
                          onPressed: _searchController.clear,
                        ),
                  filled: true,
                  fillColor: Constants.bgInput,
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Constants.borderColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Constants.amberFill),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // LayoutBuilder(
              //   builder: (context, constraints) {
              //     final columns = constraints.maxWidth < 600 ? 2 : 3;
              //     final cardWidth = (constraints.maxWidth -
              //         ((columns - 1) * 8)) /
              //         columns;
              //
              //     return Wrap(
              //       spacing: 8,
              //       runSpacing: 8,
              //       children: [
              //         SizedBox(
              //           width: cardWidth,
              //           child: _summaryCard(
              //             'Supplied qty',
              //             suppliedQuantity,
              //             Icons.check_circle,
              //             Constants.green,
              //           ),
              //         ),
              //         SizedBox(
              //           width: cardWidth,
              //           child: _summaryCard(
              //             'Pending qty',
              //             pendingQuantity,
              //             Icons.pending,
              //             Constants.amber,
              //           ),
              //         ),
              //         SizedBox(
              //           width: cardWidth,
              //           child: _summaryCard(
              //             'Partial items',
              //             partialCount,
              //             Icons.timelapse,
              //             Constants.accent,
              //           ),
              //         ),
              //       ],
              //     );
              //   },
              // ),
            ],
          ),
        ),

        // ========================================================
        // REPORT
        // ========================================================

        Expanded(
          child: _loading
              ? const Center(
            child: CircularProgressIndicator(
              color: Constants.amberFill,
            ),
          )
              : visibleItems.isEmpty
              ? const Center(
              child: Text(
                'No supply records found.',
                style: TextStyle(color: Constants.textSecondary),
              ),
          )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return constraints.maxWidth < 700
                        ? _buildReportList(visibleItems)
                        : _buildReportTable(visibleItems);
                  },
                ),
        ),
      ],
    ),
  );
}

// ============================================================
// DATE TEXT
// ============================================================

String _dateText() {
  if (_startDate == null) {
    return 'Select date';
  }

  final start = DateFormat(
    'dd MMM yyyy',
  ).format(_startDate!);

  if (_endDate == null ||
      _endDate == _startDate) {
    return start;
  }

  final end = DateFormat(
    'dd MMM yyyy',
  ).format(_endDate!);

  return '$start - $end';
}

// ============================================================
// BRANCH DROPDOWN
// ============================================================

Widget _branchDropdown(Datafeed datafeed) {

  return DropdownButtonFormField<String>(
    value: _selectedBranchId,
    decoration: InputDecoration(
      labelText: 'Branch',
      labelStyle: const TextStyle(color: Constants.textSecondary),
      prefixIcon: const Icon(
        Icons.store,
        color: Constants.textSecondary,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Constants.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Constants.amberFill),
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    items: [
      const DropdownMenuItem<String>(
        value: null,
          child: Text(
            'All Branches',
            style: TextStyle(color: Constants.textPrimary),
          ),
      ),
      // Replace this section with your actual branches.
      ...datafeed.branches.map(
            (branch) {
          return DropdownMenuItem<String>(
            value: branch.id,
            child: Text(branch.branchname,
                style: const TextStyle(color: Constants.textPrimary)),
          );
        },
      ),
    ],
    onChanged: (value) {
      setState(() {
        _selectedBranchId = value;
      });

      _loadReport();
    },
  );
}

// ============================================================
// FILTER BUTTON
// ============================================================

Widget _filterButton({
  required IconData icon,
  required String title,
  required String value,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Constants.borderColor,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Constants.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Constants.textSecondary,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Constants.textPrimary,
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

// ============================================================
// SUMMARY CARD
// ============================================================

Widget _summaryCard(
    String title,
    num value,
    IconData icon,
    Color color,
    ) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 22,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Constants.textSecondary,
              ),
            ),
            Text(
              _formatNumber(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ============================================================
// REPORT TABLE
// ============================================================

Widget _buildReportList(List<Map<String, dynamic>> items) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
    itemCount: items.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final item = items[index];
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Constants.bgCard,
          border: Border.all(color: Constants.borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['item'].toString(),
                    style: const TextStyle(
                      color: Constants.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                //_statusBadge(item['status'].toString()),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item['branchname']}  |  ${item['barcode']}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Constants.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
               // _mobileMetric('Qty', item['quantity']),
                _mobileMetric('Supplied', item['suppliedQuantity'],
                    color: Constants.green),
                _mobileMetric('Pending', item['pendingQuantity'],
                    color: Constants.amber),
                //_mobileMetric('Pieces', item['pieces']),
               // _mobileMetric('Transactions', item['transactionCount']),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _mobileMetric(String label, dynamic value, {Color? color}) {
  return SizedBox(
    width: 92,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: Constants.textSecondary,
              fontSize: 11,
            )),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: TextStyle(
            color: color ?? Constants.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _buildReportTable(List<Map<String, dynamic>> items) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
          ),
          child: DataTable(
            dividerThickness: 0.5,
            dataRowColor: WidgetStateProperty.all(Constants.bgDark),
            dataTextStyle: const TextStyle(color: Constants.textPrimary),
            //dividerColor: Constants.borderColor,
            headingRowColor:
            WidgetStateProperty.all(
              Constants.bgCard,
            ),
            headingTextStyle:
            const TextStyle(
              color: Constants.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            columns: const [
              DataColumn(
                label: Text('#'),
              ),
              DataColumn(
                label: Text('Item'),
              ),
              // DataColumn(
              //   label: Text('Barcode'),
              // ),
              DataColumn(
                label: Text('Branch'),
              ),
              // DataColumn(
              //   label: Text('Qty'),
              // ),
              DataColumn(
                label: Text('Supplied'),
              ),
              DataColumn(
                label: Text('Pending'),
              ),
              // DataColumn(
              //   label: Text('Pieces'),
              // ),
              // DataColumn(
              //   label: Text('Transactions'),
              // ),
              // DataColumn(
              //   label: Text('Status'),
              // ),
            ],
            rows: List.generate(
              items.length,
                  (index) {
                final item =
                items[index];

                return DataRow(
                  cells: [
                    DataCell(
                      Text('${index + 1}'),
                    ),
                    DataCell(
                      Text(
                        item['item']
                            .toString(),
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                    // DataCell(
                    //   Text(
                    //     item['barcode']
                    //         .toString(),
                    //   ),
                    // ),
                    DataCell(
                      Text(
                        item['branchname']
                            .toString(),
                      ),
                    ),
                    // DataCell(
                    //   Text(
                    //     _formatNumber(
                    //       item['quantity'],
                    //     ),
                    //   ),
                    // ),
                    DataCell(
                      Text(
                        _formatNumber(
                          item['suppliedQuantity'],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatNumber(
                          item['pendingQuantity'],
                        ),
                      ),
                    ),
                    // DataCell(
                    //   Text(
                    //     _formatNumber(
                    //       item['pieces'],
                    //     ),
                    //   ),
                    // ),
                    // DataCell(
                    //   Text(
                    //     item[
                    //     'transactionCount']
                    //         .toString(),
                    //   ),
                    // ),
                    // DataCell(
                    //   _statusBadge(
                    //     item['status']
                    //         .toString(),
                    //   ),
                    // ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================
// STATUS BADGE
// ============================================================

Widget _statusBadge(String status) {
  late Color color;
  late IconData icon;
  late String text;

  switch (status) {
    case 'approved':
      color = Constants.green;
      icon = Icons.check_circle;
      text = 'Approved';
      break;

    case 'partial':
      color = Constants.accent;
      icon = Icons.timelapse;
      text = 'Partial';
      break;

    default:
      color = Constants.amber;
      icon = Icons.pending;
      text = 'Pending';
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// NUMBER FORMAT
// ============================================================

String _formatNumber(dynamic value) {
  final number =
      double.tryParse(
        value?.toString() ?? '0',
      ) ??
          0;

  if (number == number.roundToDouble()) {
    return number.toInt().toString();
  }

  return number.toStringAsFixed(2);
}
}