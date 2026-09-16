import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/newstock.dart';
import 'package:kologsoft/screens/stockdetailpage.dart';
import 'package:kologsoft/screens/stockinvoice.dart';
import 'package:provider/provider.dart';
import '../models/appModuls.dart';
import '../providers/StockProvider.dart';

class StockListTable extends StatefulWidget {
  const StockListTable({super.key});

  @override
  State<StockListTable> createState() => _StockListTableState();
}

class _StockListTableState extends State<StockListTable> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;

  // Pagination variables
  int _rowsPerPage = 10;
  int _currentPage = 0;

  // Data loading state
  bool _isLoading = false;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _displayData = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async{
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.getdata();
      _loadData();
    });
  }
  StreamSubscription? _subscription;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = Provider.of<StockProvider>(context, listen: false);

    _subscription = provider.stockStream(
      collectionName: 'stock_transactions',
      startDate: _isDateRangeActive ? _startDate : null,
      endDate: _isDateRangeActive ? _endDate : null,
      branchfield: 'staffbranchid',
      datefield: 'invoicedate',
    ).listen((snapshot) {
      if (snapshot.isNotEmpty) {
        setState(() {
          _allData = snapshot;
          _totalCount = _allData.length;
          _applySearchAndPagination();
          _isLoading = false;
        });
      }
    }, onError: (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    });
  }


  // Future<void> _loadData() async {
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final provider = Provider.of<StockProvider>(context, listen: false);
  //     final snapshot = await provider.stockStream(
  //       collectionName: 'stock_transactions',
  //       startDate: _isDateRangeActive ? _startDate : null,
  //       endDate: _isDateRangeActive ? _endDate : null,
  //       branchfield: 'staffbranchid', datefield: 'invoicedate',
  //     ).first;
  //
  //     if (snapshot != null) {
  //       _allData = snapshot;
  //       _totalCount = _allData.length;
  //       _applySearchAndPagination();
  //     }
  //   } catch (e) {
  //     print("Error loading data: $e");
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  void _applySearchAndPagination() {
    var filtered = _allData.where((doc) {
      if (searchQuery.isEmpty) return true;
      return doc.values.any((value) {
        if (value == null) return false;
        return value.toString().toLowerCase().contains(searchQuery.toLowerCase());
      });
    }).toList();

    _totalCount = filtered.length;

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) > _totalCount
        ? _totalCount
        : startIndex + _rowsPerPage;

    _displayData = filtered.sublist(
      startIndex,
      endIndex,
    );

    setState(() {});
  }

  @override
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
          _currentPage = 0;
        });
        _loadData();
      }
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
      _currentPage = 0;
    });
    _loadData();
  }

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  @override
  void dispose() {
    _subscription?.cancel();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  List<Widget> _buildAppBarActions() {
    final stock = Provider.of<StockProvider>(context);
    final actions = <Widget>[
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
      IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.refresh, color: Colors.white70),
        ),
        onPressed: _loadData,
        tooltip: 'Refresh',
      ),
      const SizedBox(width: 8),
    ];

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text("Stocked Item List"),
        actions: _buildAppBarActions(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF415A77),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewStock()),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  child: TextFormField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _currentPage = 0;
                      });
                      _applySearchAndPagination();
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
                            _currentPage = 0;
                          });
                          _applySearchAndPagination();
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
              if (_startDate != null && _endDate != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearDateRange,
                        child: const Icon(Icons.close, size: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              /// RESPONSIVE VIEW
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: Text("no data"),
                )
                    : _displayData.isEmpty
                    ? Center(
                  child: Text(
                    searchQuery.isEmpty
                        ? "No stock items available"
                        : "No items found matching '$searchQuery'",
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 800;

                    return Column(
                      children: [
                        // Content - ListView or DataTable
                        Expanded(
                          child: isMobile
                              ? _buildMobileView()
                              : _buildDesktopView(constraints),
                        ),

                        // Pagination Controls
                        _buildPaginationControls(context),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile View - ListView
  Widget _buildMobileView() {
    return ListView.builder(
      controller: verticalController,
      padding: const EdgeInsets.all(8),
      itemCount: _displayData.length,
      itemBuilder: (context, index) {
        final data = _displayData[index];
        final globalIndex = (_currentPage * _rowsPerPage) + index;
        return _buildMobileCard(context, data, globalIndex);
      },
    );
  }

  // Desktop View - DataTable
  Widget _buildDesktopView(BoxConstraints constraints) {
    return SingleChildScrollView(
      controller: verticalController,
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        controller: horizontalController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF1B263B),
            ),
            columnSpacing: 10,
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            dataTextStyle: const TextStyle(
              color: Colors.white,
            ),
            columns: const [
              DataColumn(label: Text('#')),
              //DataColumn(label: Text('CID')),
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('Waybill')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Entry Date')),
              DataColumn(label: Text('Supplier')),
              DataColumn(label: Text('Branch')),
              DataColumn(label: Text('Mode')),
              DataColumn(label: Text('Stock Value')),
              DataColumn(label: Text('Action')),
            ],
            rows: _displayData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final globalIndex = (_currentPage * _rowsPerPage) + index;
              return _buildDesktopRow(context, data, globalIndex);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Pagination Controls - Fixed overflow issue
  Widget _buildPaginationControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 500;

          if (isSmall) {
            // Compact layout for very small screens
            return Column(
              children: [
                // Rows per page and page info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRowsPerPageSelector(isSmall: true),
                    _buildPageInfo(isSmall: true),
                  ],
                ),
                const SizedBox(height: 8),
                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildNavigationButtons(isSmall: true),
                ),
              ],
            );
          }

          // Normal layout
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRowsPerPageSelector(isSmall: false),
              _buildPageInfo(isSmall: false),
              Row(
                children: _buildNavigationButtons(isSmall: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRowsPerPageSelector({required bool isSmall}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isSmall ? "Rows:" : "Rows per page:",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmall ? 12 : 14,
          ),
        ),
        const SizedBox(width: 4),
        DropdownButton<int>(
          value: _rowsPerPage,
          dropdownColor: const Color(0xFF1B263B),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 12 : 14,
          ),
          underline: Container(
            height: 1,
            color: Colors.white24,
          ),
          items: const [
            DropdownMenuItem(value: 5, child: Text('5')),
            DropdownMenuItem(value: 10, child: Text('10')),
            DropdownMenuItem(value: 25, child: Text('25')),
            DropdownMenuItem(value: 50, child: Text('50')),
            DropdownMenuItem(value: 100, child: Text('100')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _rowsPerPage = value;
                _currentPage = 0;
              });
              _applySearchAndPagination();
            }
          },
        ),
      ],
    );
  }

  Widget _buildPageInfo({required bool isSmall}) {
    final start = (_currentPage * _rowsPerPage) + 1;
    final end = ((_currentPage + 1) * _rowsPerPage) > _totalCount
        ? _totalCount
        : (_currentPage + 1) * _rowsPerPage;

    return Text(
      isSmall ? '$start-$end' : '$start - $end of $_totalCount',
      style: TextStyle(
        color: Colors.white70,
        fontSize: isSmall ? 12 : 14,
      ),
    );
  }

  List<Widget> _buildNavigationButtons({required bool isSmall}) {
    final buttonSize = isSmall ? 28.0 : 36.0;
    final iconSize = isSmall ? 16.0 : 20.0;

    return [
      IconButton(
        icon: Icon(
          Icons.first_page,
          color: Colors.white70,
          size: iconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(buttonSize, buttonSize)),
        onPressed: _currentPage > 0 ? () {
          setState(() => _currentPage = 0);
          _applySearchAndPagination();
        } : null,
        tooltip: 'First page',
      ),
      IconButton(
        icon: Icon(
          Icons.chevron_left,
          color: Colors.white70,
          size: iconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(buttonSize, buttonSize)),
        onPressed: _currentPage > 0 ? () {
          setState(() => _currentPage--);
          _applySearchAndPagination();
        } : null,
        tooltip: 'Previous page',
      ),
      IconButton(
        icon: Icon(
          Icons.chevron_right,
          color: Colors.white70,
          size: iconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(buttonSize, buttonSize)),
        onPressed: ((_currentPage + 1) * _rowsPerPage) < _totalCount ? () {
          setState(() => _currentPage++);
          _applySearchAndPagination();
        } : null,
        tooltip: 'Next page',
      ),
      IconButton(
        icon: Icon(
          Icons.last_page,
          color: Colors.white70,
          size: iconSize,
        ),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size(buttonSize, buttonSize)),
        onPressed: ((_currentPage + 1) * _rowsPerPage) < _totalCount ? () {
          setState(() {
            _currentPage = (_totalCount / _rowsPerPage).ceil() - 1;
          });
          _applySearchAndPagination();
        } : null,
        tooltip: 'Last page',
      ),
    ];
  }

  // Mobile Card View
  Widget _buildMobileCard(BuildContext context, Map<String, dynamic> data, int index) {
    final invoiceDate = data['invoicedate'] != null
        ? (data['invoicedate'] as Timestamp)
        .toDate()
        .toString()
        .substring(0, 10)
        : 'N/A';

    final stockValue = (data['netval'] ?? 0.00).toDouble();
    final value = Provider.of<Datafeed>(context, listen: false);
    final bool syncStatus = data['syncstatus'] is bool ? data['syncstatus'] as bool : false;    return Card(
      color: index.isEven
          ? const Color(0xFF0D1B2A)
          : const Color(0xFF1B263B),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blueGrey,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  "GHC ${stockValue.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Invoice
            Row(
              children: [
                const Text(
                  "Invoice: ",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final invoice = data['invoice']?.toString() ?? '';
                      await Clipboard.setData(ClipboardData(text: invoice));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invoice copied')),
                      );
                    },
                    child: Text(
                      data['invoice']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Waybill
            Row(
              children: [
                const Text(
                  "Waybill: ",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final waybill = data['waybill']?.toString() ?? '';
                      await Clipboard.setData(ClipboardData(text: waybill));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Waybill copied')),
                      );
                    },
                    child: Text(
                      data['waybill']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Text(
              "Date: $invoiceDate",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              "Supplier: ${data['suppliername'] ?? ''}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              "Branch: ${data['branchname'] ?? ''}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              "Mode: ${data['purchasetype'] ?? ''}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),

            const Divider(
              color: Colors.white24,
            ),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.visibility,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailsPage(
                          data: data,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.print,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                  onPressed: () async {
                    final rawItems = data['items'];
                    List<Map<String, dynamic>> items = [];

                    if (rawItems is List) {
                      items = rawItems
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    } else if (rawItems is Map) {
                      items = rawItems.entries
                          .map((entry) {
                        return {
                          'key': entry.key,
                          ...Map<String, dynamic>.from(
                              entry.value),
                        };
                      }).toList();
                    }

                    newStockInvoicePdf(data, items);
                  },
                ),
                if (value.canEdit(AppModules.stock))
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
                          builder: (_) => NewStock(
                            docId: data['docid'],
                            data: data,
                          ),
                        ),
                      );
                    },
                  ),
                if (value.canDelete(AppModules.stock))
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _handleDelete(context, data, value),
                  ),

                if (!syncStatus)
                  IconButton(
                    icon: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                    onPressed: () => _handleSync(context, data),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Desktop Row View
  DataRow _buildDesktopRow(BuildContext context, Map<String, dynamic> data, int index) {
    final invoiceDate = data['invoicedate'] != null
        ? (data['invoicedate'] as Timestamp)
        .toDate()
        .toString()
        .substring(0, 10)
        : 'N/A';
    final entryDate = data['createdat'] != null
        ? (data['createdat'] as Timestamp)
        .toDate()
        .toString()
        .substring(0, 10)
        : 'N/A';

    final stockValue = (data['netval'] ?? 0.00).toDouble();
    final value = Provider.of<Datafeed>(context, listen: false);
    final bool syncStatus = data['syncstatus'] is bool ? data['syncstatus'] as bool : false;    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
          return index.isEven
              ? const Color(0xFF0D1B2A)
              : const Color(0xFF1B263B);
        },
      ),
      cells: [
        DataCell(Text('${index + 1}')),
        //DataCell(Text(data['companyid'])),
        DataCell(
          InkWell(
            onTap: () async {
              final invoice = data['invoice']?.toString() ?? '';
              await Clipboard.setData(ClipboardData(text: invoice));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice copied')),
              );
            },
            child: Text(data['invoice']?.toString() ?? ''),
          ),
        ),
        DataCell(
          InkWell(
            onTap: () async {
              final waybill = data['waybill']?.toString() ?? '';
              await Clipboard.setData(ClipboardData(text: waybill));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Waybill copied')),
              );
            },
            child: Text(data['waybill']?.toString() ?? ''),
          ),
        ),
        DataCell(Text(invoiceDate)),
        DataCell(Text(entryDate)),
        DataCell(
          Text(data['suppliername']?.toString() ?? ''),
        ),
        DataCell(
          Text(data['branchname']?.toString() ?? ''),
        ),
        DataCell(
          Text(data['purchasetype']?.toString() ?? ''),
        ),
        DataCell(
          Text("GHC ${stockValue.toStringAsFixed(2)}"),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.visibility,
                  color: Colors.tealAccent,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockDetailsPage(
                        data: data,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.print,
                  color: Colors.blueGrey,
                  size: 20,
                ),
                onPressed: () async {
                  final rawItems = data['items'];
                  List<Map<String, dynamic>> items = [];

                  if (rawItems is List) {
                    items = rawItems
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  } else if (rawItems is Map) {
                    items = rawItems.entries.map((entry) {
                      return {
                        'key': entry.key,
                        ...Map<String, dynamic>.from(entry.value),
                      };
                    }).toList();
                  }

                  newStockInvoicePdf(data, items);
                },
              ),
              if (value.canEdit(AppModules.stock))
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
                        builder: (_) => NewStock(
                          docId: data['docid'],
                          data: data,
                        ),
                      ),
                    );
                  },
                ),
              if (value.canDelete(AppModules.stock))
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _handleDelete(context, data, value),
                ),
              if (!syncStatus)
                IconButton(
                  icon: const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.blue,
                    size: 20,
                  ),
                  onPressed: () => _handleSync(context, data),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Delete handler
  void _handleDelete(BuildContext context, Map<String, dynamic> data, Datafeed value) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          "Delete Stock Invoice #${data['invoice']}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Are you sure you want to delete this stock invoice?",
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final overlay = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (context) => Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
      overlay.insert(overlayEntry);

      try {
        final rawItems = data['items'];
        List<Map<String, dynamic>> items = [];

        if (rawItems is List) {
          items = rawItems
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else if (rawItems is Map) {
          items = rawItems.values
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        final insufficient = <String>[];

        for (final item in items) {
          final itemId = item['itemid']?.toString() ?? '';
          final itemName = item['item']?.toString() ?? itemId;

          final piecesToDelete =
          (item['stockin_pieces'] ?? item['pieces'] ?? 0) as num;

          final currentBalance =
          await value.fetchItemCurrentBalance(
            itemId: itemId,
            selectedBranch: data['branchid'],
          );

          if (currentBalance < piecesToDelete) {
            insufficient.add(
              '$itemName\n'
                  'Available: ${currentBalance.toInt()} pcs\n'
                  'Trying to remove: ${piecesToDelete.toInt()} pcs',
            );
          }
        }
        if (insufficient.isNotEmpty) {
          overlayEntry.remove();
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Cannot Delete Stock Invoice'),
                content: SingleChildScrollView(
                  child: Text(
                    'The following items no longer have enough stock to reverse this transaction:\n\n'
                        '${insufficient.join('\n\n')}',
                  ),
                ),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Ok"),
                  ),

                ],
              ),
            );
          }
          return;
        }
        await db.runTransaction((transaction) async {
          final stockRef =
          db.collection('stock_transactions').doc(data['docid']);

          final stockSnap = await transaction.get(stockRef);

          if (!stockSnap.exists) {
            throw Exception('Stock transaction not found');
          }

          final stockData = stockSnap.data()!;

          final purchaseType = (stockData['purchasetype'] ?? '').toString().toLowerCase();

          // if (purchaseType == 'credit') {
          //   final supplierId = stockData['supplierid'];
          //
          //   final invoiceAmount =
          //       (stockData['netval'] as num?)?.toDouble() ?? 0.0;
          //
          //   final supplierRef =
          //   db.collection('suppliers').doc(supplierId);
          //
          //   final supplierSnap = await transaction.get(supplierRef);
          //
          //   if (supplierSnap.exists) {
          //     final currentCredit =
          //         (supplierSnap.data()?['creditaccount'] as num?)
          //             ?.toDouble() ??
          //             0.0;
          //
          //     transaction.update(supplierRef, {
          //       'creditaccount': currentCredit - invoiceAmount,
          //       'lastupdate': FieldValue.serverTimestamp(),
          //     });
          //   }
          // }

          final deletedStockRef = db.collection('deletedstock').doc(stockData['docid']);

          final deletedData = Map<String, dynamic>.from(stockData);

          deletedData.addAll({
            'deletedat': FieldValue.serverTimestamp(),
            'deletedby': value.staff,
            'reason': 'Deleted Stock Invoice',
            'deletetype': 'new stock entry',
          });

          transaction.set(deletedStockRef, deletedData);
          transaction.delete(stockRef);
        });
        overlayEntry.remove();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Stock invoice deleted successfully",
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        overlayEntry.remove();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Delete failed: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Sync handler
  void _handleSync(BuildContext context, Map<String, dynamic> data) async {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
    overlay.insert(overlayEntry);

    try {
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.syncTransactionToReport(data['docid']);
      overlayEntry.remove();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Stock invoice synced successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      overlayEntry.remove();
      print("Sync failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}