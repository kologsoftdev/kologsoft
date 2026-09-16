import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/itemregmodel.dart';
import '../paymentwidgets/BarcodeScannerScreen.dart';


class StockTake extends StatefulWidget {
  const StockTake({super.key});

  @override
  State<StockTake> createState() => _StockTakeState();
}

class _StockTakeState extends State<StockTake> {
  // ---------------------------------------------------------------------------
  // Branch
  // ---------------------------------------------------------------------------

  String? _selectedBranchId;
  String? _selectedBranchName;

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';

  // Complete locally loaded branch items.
  List<ItemModel> _allBranchItems = [];

  // Items currently displayed after local filtering.
  List<ItemModel> _branchItems = [];

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _loading = false;

  final Map<String, num> _currentBalances = {};

  final Map<String, TextEditingController>
  _newBalanceControllers = {};

  final Map<String, bool> _updating = {};

  final Map<String, String?> _rowMessages = {};

  final Map<String, bool> _rowSuccess = {};
  final Set<String> _updatedItems = <String>{};


  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    Future.microtask(() async {
      final provider = context.read<Datafeed>();

      await provider.fetchItems();
      await provider.fetchBranches();
      await provider.fetchstockreport();

      if (!mounted) return;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);

    _searchController.dispose();
    _searchFocus.dispose();

    for (final controller
    in _newBalanceControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (_searchQuery == query) return;

    setState(() {
      _searchQuery = query;
      _applyLocalFilter();
    });
  }

  void _applyLocalFilter() {
    if (_searchQuery.isEmpty) {
      _branchItems = List<ItemModel>.from(
        _allBranchItems,
      );
      return;
    }

    _branchItems = _allBranchItems.where((item) {
      final name = item.name.toLowerCase();
      final barcode = item.barcode.toLowerCase();
      final category = item.pcategory.toLowerCase();
      final id = item.id.toLowerCase();

      return name.contains(_searchQuery) ||
          barcode.contains(_searchQuery) ||
          category.contains(_searchQuery) ||
          id.contains(_searchQuery);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.requestFocus();
  }


  num _toNum(dynamic value) {
    if (value == null) return 0;

    if (value is num) return value;

    return num.tryParse(
      value.toString(),
    ) ??
        0;
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  TextEditingController _controllerFor(
      String itemId,
      ) {
    return _newBalanceControllers.putIfAbsent(
      itemId,
          () => TextEditingController(
        text: _formatNumber(
          _currentBalances[itemId] ?? 0,
        ),
      ),
    );
  }

  num _newBalanceFor(String itemId) {
    final value =
    _controllerFor(itemId).text.trim();

    if (value.isEmpty) return 0;

    return _toNum(value);
  }

  num _differenceFor(String itemId) {
    final current =
        _currentBalances[itemId] ?? 0;

    final newBalance =
    _newBalanceFor(itemId);

    return newBalance - current;
  }

  String _differenceText(num difference) {
    if (difference > 0) {
      return '+${_formatNumber(difference)}';
    }

    return _formatNumber(difference);
  }

  // ---------------------------------------------------------------------------
  // Read current balance DIRECTLY from ItemModel
  // ---------------------------------------------------------------------------

  num _getBranchBalance(
      ItemModel item,
      String branchId,
      ) {
    final branchBalance = item.branchbalance;

    if (branchBalance == null) return 0;

    final rawBranch = branchBalance[branchId];

    if (rawBranch == null) return 0;

    if (rawBranch is Map) {
      return _toNum(
        rawBranch['netpieces'],
      );
    }

    return 0;
  }


  Future<void> _loadBranchItems(
      String branchId,
      ) async {
    final provider = context.read<Datafeed>();

    setState(() {
      _loading = true;

      _allBranchItems = [];
      _branchItems = [];
      _currentBalances.clear();
      _rowMessages.clear();
      _rowSuccess.clear();
      _updatedItems.clear();
      _searchController.clear();
      _searchQuery = '';
    });

    try {

      await provider.fetchstockreport(
        selectedDate: DateTimeRange(
          start: DateTime(
            2000,
            1,
            1,
          ),
          end: DateTime.now(),
        ),
        selectedBranch: branchId,
      );


      final branchItems = provider.items
          .where(
            (item) => item.isActive == true,
      )
          .where(
            (item) =>
        item.branchbalance != null &&
            item.branchbalance!.containsKey(
              branchId,
            ),
      )
          .toList();

      /*
       * Sort locally.
       */
      branchItems.sort(
            (a, b) => a.name
            .toLowerCase()
            .compareTo(
          b.name.toLowerCase(),
        ),
      );

      /*
       * Read every current balance locally.
       */
      for (final item in branchItems) {
        final balance = _getBranchBalance(
          item,
          branchId,
        );

        _currentBalances[item.id] = balance;

        final controller =
        _controllerFor(item.id);

        controller.text =
            _formatNumber(balance);
      }

      if (!mounted) return;

      setState(() {
        _allBranchItems = branchItems;

        _branchItems =
        List<ItemModel>.from(
          branchItems,
        );

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Error loading branch items: $e',
        success: false,
      );
    }
  }

  Future<void> _scanBarcode() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: BarcodeScannerDialog(),
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      _searchController.text = result;
      // Optional: make sure the search field receives focus.
      _searchFocus.requestFocus();
    }
  }


  Future<void> _updateItem(
      ItemModel item,
      ) async {
    final branchId = _selectedBranchId;

    if (branchId == null) return;

    final itemId = item.id;
    final barcode = item.barcode;

    final currentBalance = _currentBalances[itemId] ?? 0;

    final newBalance =_newBalanceFor(itemId);

    final difference = newBalance - currentBalance;

    if (newBalance < 0) {
      setState(() {
        _rowMessages[itemId] =
        'Balance cannot be negative.';

        _rowSuccess[itemId] = false;
      });

      return;
    }

    if (difference == 0) {
      setState(() {
        _rowMessages[itemId] =
        'No balance change.';

        _rowSuccess[itemId] = true;
      });

      return;
    }

    setState(() {
      _updating[itemId] = true;
      _rowMessages[itemId] = null;
    });

    try {
      final provider =
      context.read<Datafeed>();

      final companyId = provider.companyid;

      final today = DateTime.now();

      final year =
      today.year.toString().padLeft(
        4,
        '0',
      );

      final month =
      today.month.toString().padLeft(
        2,
        '0',
      );

      final day =
      today.day.toString().padLeft(
        2,
        '0',
      );

      final summaryDate ='$year-$month-$day';

      final summaryId ='${companyId}_$summaryDate';
      final stocktakeId = '${summaryDate}_${branchId}$itemId';
      final stockReportRef = provider.db.collection('stockreport').doc(summaryId);

      await stockReportRef.set({
        'companyid':companyId,
        'summaryid':summaryId,
        'summarydate':summaryDate,
        'items': {
          branchId: {
            itemId: {
              'oldbalance':currentBalance,
              'itemid':itemId,
              'item': item.name,
              'stocktake':true,
              'barcode':barcode,
              'newstock':FieldValue.increment( difference, ),
              'lastupdate':FieldValue.serverTimestamp(),
            },
          },
        },
        'branchbalance': {
          branchId: {
            'lastupdate':
            FieldValue.serverTimestamp(),
          },
        },
      },SetOptions(merge: true, ),);

      await provider.db.collection('itemsreg').doc(itemId) .set( {
          'branchbalance': {
            branchId: {
              'netpieces': newBalance,
              'lastupdate':
              FieldValue.serverTimestamp(),
            },
          },
        },SetOptions(merge: true,),);

      final stocktakeRef = provider.db.collection('stocktake').doc(stocktakeId);

      await stocktakeRef.set( {
          'itemid':itemId,
          'item':item.name,
          'barcode':barcode,
          'oldbalance':currentBalance,
          'newBalance':newBalance,
          'difference':difference,
          'date':summaryDate,
          'createdby':provider.staff,
          'companyid':provider.companyid,
          'branchid':branchId,
        },SetOptions( merge: true, ),);

      if (!mounted) return;

      setState(() {

        _currentBalances[itemId] = newBalance;
        _controllerFor(itemId).text = _formatNumber(newBalance);
        _updatedItems.add(itemId);
        _rowMessages[itemId] =
        'Updated ${item.name}: '
            '${_formatNumber(currentBalance)} → '
            '${_formatNumber(newBalance)} '
            '(${_differenceText(difference)})';

        _rowSuccess[itemId] = true;

        _updating[itemId] = false;
      });
    } catch (e) {
      print(e);
      if (!mounted) return;

      setState(() {
        _updating[itemId] = false;

        _rowMessages[itemId] =
        'Error: $e';

        _rowSuccess[itemId] = false;
      });
    }
  }

  void _showMessage(
      String message, {
        required bool success,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        success
            ? Colors.green[700]
            : Colors.red[700],
      ),
    );
  }


  static const Color _background =
  Color(0xFF0F1826);

  static const Color _appBar =
  Color(0xFF111E2E);

  static const Color _card =
  Color(0xFF162032);

  static const Color _input =
  Color(0xFF1B2A3E);

  static const Color _primary =
  Color(0xFF3B8BEB);

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white24,
        fontSize: 12,
      ),
      filled: true,
      fillColor: _input,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      suffixIcon: suffixIcon,
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(8),
        borderSide:
        const BorderSide(
          color: Colors.white10,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(8),
        borderSide:
        const BorderSide(
          color: _primary,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _appBar,
        elevation: 0,
        iconTheme:
        const IconThemeData(
          color: Colors.white70,
        ),
        title: const Text(
          'Stock Take',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        bottom:
        PreferredSize(
          preferredSize:
          const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ),
      body: Consumer<Datafeed>(
        builder:
            (context, provider, _) {
          return LayoutBuilder(
            builder:
                (context, constraints) {
              final isMobile =
                  constraints.maxWidth <
                      800;

              return SingleChildScrollView(
                padding:
                EdgeInsets.symmetric(
                  horizontal:
                  isMobile
                      ? 12
                      : 28,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
                  children: [
                    _buildHeader(),

                    const SizedBox(
                      height: 16,
                    ),


                    _buildFilters(
                      provider,
                      isMobile,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    if (_loading)
                      _buildLoading()
                    else if (_selectedBranchId ==null)

                       _buildSelectBranchMessage()
                    else
                      _buildItemsTable(
                        isMobile,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return  Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 650,
            ),
            child:Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: const Color(
          0xFF1A3A5C,
        ).withOpacity(.5),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          _primary.withOpacity(.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select a branch, search for an item, '
                  'enter the physical balance and update it.',
              style: TextStyle(
                color: Colors.white
                    .withOpacity(.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    )));
  }

  // ---------------------------------------------------------------------------
  // Branch + Search
  // ---------------------------------------------------------------------------

  Widget _buildFilters(
      Datafeed provider,
      bool isMobile,
      ) {
    final branches =
    provider.branches
        .where(
          (b) =>
      b.id != null &&
          b.id!.isNotEmpty,
    )
        .fold<
        Map<String, dynamic>>(
      {},
          (map, branch) {
        map[branch.id!] =
            branch;
        return map;
      },
    )
        .values
        .toList();

    final branchField =
    DropdownButtonFormField<
        String>(
      value: _selectedBranchId,
      isExpanded: true,
      dropdownColor: _input,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration:
      _inputDecoration(
        hint: 'Select branch...',
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: Colors.white38,
      ),
      items: branches.map(
            (branch) {
          return DropdownMenuItem<
              String>(
            value:
            branch.id as String,
            child: Text(
              branch.branchname
              as String,
              style:
              const TextStyle(
                color:
                Colors.white,
              ),
            ),
          );
        },
      ).toList(),
      onChanged:
      _loading
          ? null
          : (value) async {
        if (value ==
            null) {
          return;
        }

        final branch =
        branches.firstWhere(
              (b) =>
          b.id == value,
        );

        setState(() {
          _selectedBranchId =
              value;

          _selectedBranchName =
              branch.branchname;
        });

        await _loadBranchItems(
          value,
        );
      },
    );

    final searchField = TextField(
    controller: _searchController,
    focusNode: _searchFocus,
    enabled: _selectedBranchId != null && !_loading,
    style: const TextStyle(
    color: Colors.white,
    fontSize: 13,
    ),
    decoration: _inputDecoration(
    hint: 'Search item, barcode or category...',
    suffixIcon: _searchQuery.isNotEmpty
    ? IconButton(
    tooltip: 'Clear search',
    icon: const Icon(
    Icons.close,
    color: Colors.white38,
    size: 17,
    ),
    onPressed: _clearSearch,
    )
        : const Icon(
    Icons.search,
    color: Colors.white30,
    size: 18,
    ),
    ),
    );

    final qrcode = IconButton(
    icon: const Icon(
    Icons.qr_code_scanner,
    color: Colors.white70,
    ),
    onPressed: _scanBarcode,
    tooltip: 'Scan Barcode/QR Code',
    );

    final searchWithQr = Row(
    children: [
    Expanded(
    child: searchField,
    ),
    const SizedBox(width: 4),
    qrcode,
    ],
    );

    return Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
    constraints: const BoxConstraints(
    maxWidth: 650,
    ),
    child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
    color: Colors.white10,
    ),
    ),
    child: isMobile
    ? Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    const Text(
    'BRANCH',
    style: TextStyle(
    color: Colors.white38,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    ),
    ),

    const SizedBox(height: 7),

    branchField,

    const SizedBox(height: 14),

    const Text(
    'SEARCH ITEMS',
    style: TextStyle(
    color: Colors.white38,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    ),
    ),

    const SizedBox(height: 7),

    searchWithQr,
    ],
    )
        : Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
    Expanded(
    flex: 2,
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    const Text(
    'BRANCH',
    style: TextStyle(
    color: Colors.white38,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    ),
    ),

    const SizedBox(height: 7),

    branchField,
    ],
    ),
    ),

    const SizedBox(width: 14),

    Expanded(
    flex: 3,
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    const Text(
    'SEARCH ITEMS',
    style: TextStyle(
    color: Colors.white38,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    ),
    ),

    const SizedBox(height: 7),

    searchWithQr,
    ],
    ),
    ),
    ],
    ),
    ),
    ),
    );

  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Widget _buildLoading() {
    return  ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: 300,
        ),
      child:const Column(
        children: [
          CircularProgressIndicator(
            color: _primary,
          ),
          SizedBox(height: 14),
          Text(
            'Loading branch items...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ));
  }

  // ---------------------------------------------------------------------------
  // Select branch
  // ---------------------------------------------------------------------------

  Widget _buildSelectBranchMessage() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 0,
        maxWidth: 300,
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: Colors.white24,
            size: 40,
          ),
          SizedBox(height: 12),
          Text(
            'Select a branch to load its items.',
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildItemsTable(
      bool isMobile,
      ) {
    if (_branchItems.isEmpty) {
      return Container(
        padding:
        const EdgeInsets.all(30),
        decoration:
        BoxDecoration(
          color: _card,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white10,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off,
              color: Colors.white24,
              size: 36,
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              _searchQuery.isEmpty
                  ? 'No active items found for this branch.'
                  : 'No items match "$_searchQuery".',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return
      Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 800,
                minWidth: 0,
              ),
      child:Container(
      decoration:
      BoxDecoration(
        color: _card,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .stretch,
        children: [
          Padding(
            padding:
            const EdgeInsets.all(
              16,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .table_chart_outlined,
                  color: _primary,
                  size: 18,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    _searchQuery.isEmpty
                        ? '${_branchItems.length} items — $_selectedBranchName'
                        : '${_branchItems.length} matching items — $_selectedBranchName',
                    style:
                    const TextStyle(
                      color:
                      Colors.white70,
                      fontSize: 13,
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                ),
                if (_searchQuery
                    .isNotEmpty)
                  Text(
                    'Search: $_searchQuery',
                    style:
                    const TextStyle(
                      color:
                      Colors.white30,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            color: Colors.white10,
          ),
          isMobile
              ? _buildMobileList()
              : _buildDesktopTable(),
        ],
      ),
    )));
  }

  // ---------------------------------------------------------------------------
  // Desktop table
  // ---------------------------------------------------------------------------


  Widget _buildDesktopTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
            ),
            child: Center(
              child: DataTable(
                headingRowColor:
                WidgetStateProperty.all(
                  const Color(0xFF111E2E),
                ),
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columnSpacing: 14,
                columns: const [
                  DataColumn(
                    label: Text(
                      'ITEM',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(
                      'CURRENT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'NEW BALANCE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(
                      'DIFFERENCE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'ACTION',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                rows: _branchItems
                    .map(_buildDesktopRow)
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }


  DataRow _buildDesktopRow(
      ItemModel item,
      ) {
    final itemId = item.id;

    final current = _currentBalances[itemId] ?? 0;

    final difference =
    _differenceFor(itemId);

    final controller =
    _controllerFor(itemId);

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 250,
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment
                  .center,
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  item.name,
                  // maxLines: 1,
                  // overflow:
                  // TextOverflow
                  //     .ellipsis,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        DataCell(
          Text(
            _formatNumber(current),
            style:
            const TextStyle(
              color:
              Colors.white70,
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),

        DataCell(
          SizedBox(
            width: 100,
            height: 30,
            child: TextField(
              controller:
              controller,
              keyboardType:
              const TextInputType
                  .numberWithOptions(
                decimal: true,
              ),
              style:
              const TextStyle(
                color:
                Colors.white,
                fontSize: 13,
              ),
              onChanged: (_) {
                setState(() {});
              },
              decoration:
              _inputDecoration(
                hint:
                'New balance',
              ),
            ),
          ),
        ),

        DataCell(
          _buildDifference(
            difference,
          ),
        ),

        DataCell(
          _buildUpdateButton(
            item,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Difference
  // ---------------------------------------------------------------------------

  Widget _buildDifference(
      num difference,
      ) {
    Color textColor;

    if (difference > 0) {
      textColor =
      Colors.green[300]!;
    } else if (difference < 0) {
      textColor =
      Colors.orange[300]!;
    } else {
      textColor =
          Colors.white30;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color:
        textColor.withOpacity(.08),
        borderRadius:
        BorderRadius.circular(6),
      ),
      child: Text(
        _differenceText(
          difference,
        ),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }


  Widget _buildUpdateButton(ItemModel item) {
    final itemId = item.id;

    final updating = _updating[itemId] == true;

    final difference = _differenceFor(itemId);

    final updated = _updatedItems.contains(itemId);

    if (updating) {
      return const SizedBox(
        width: 100,
        child: Center(
          child: SizedBox(
            width: 17,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primary,
            ),
          ),
        ),
      );
    }

    if (updated && difference == 0) {
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.green.withOpacity(.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 15,
              color: Colors.green[300],
            ),
            const SizedBox(width: 6),
            Text(
              'Updated',
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: difference == 0
            ? null
            : () => _updateItem(item),
        icon: const Icon(
          Icons.save_outlined,
          size: 15,
        ),
        label: const Text(
          'Update',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: Colors.white10,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white24,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }


  Widget _buildMobileList() {
    return ListView.separated(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      itemCount:
      _branchItems.length,
      separatorBuilder:
          (_, __) =>
      const Divider(
        height: 1,
        color: Colors.white10,
      ),
      itemBuilder:
          (context, index) {
        final item =
        _branchItems[index];

        final itemId = item.id;

        final current =
            _currentBalances[itemId] ??
                0;

        final difference =
        _differenceFor(
          itemId,
        );

        final controller =
        _controllerFor(
          itemId,
        );

        return Padding(
          padding:
          const EdgeInsets.all(
            14,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration:
                    BoxDecoration(
                      color: _primary
                          .withOpacity(
                        .1,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        8,
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .inventory_2_outlined,
                      color:
                      _primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(
                    width: 9,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize: 13,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          '${item.pcategory} · ${item.barcode}',
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _mobileValue(
                      'CURRENT',
                      _formatNumber(
                        current,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    TextField(
                      controller:
                      controller,
                      keyboardType:
                      const TextInputType
                          .numberWithOptions(
                        decimal: true,
                      ),
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 13,
                      ),
                      onChanged:
                          (_) {
                        setState(
                              () {},
                        );
                      },
                      decoration:
                      _inputDecoration(
                        hint:
                        'New balance',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Text(
                          'DIFFERENCE',
                          style:
                          TextStyle(
                            color:
                            Colors.white30,
                            fontSize: 9,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        _buildDifference(
                          difference,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              _buildUpdateButton(
                item,
              ),

              if (_rowMessages[
              itemId] !=
                  null) ...[
                const SizedBox(
                  height: 8,
                ),
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Icon(
                      _rowSuccess[
                      itemId] ==
                          true
                          ? Icons
                          .check_circle_outline
                          : Icons
                          .error_outline,
                      size: 15,
                      color: _rowSuccess[
                      itemId] ==
                          true
                          ? Colors.green[
                      300]
                          : Colors.red[
                      300],
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Expanded(
                      child: Text(
                        _rowMessages[
                        itemId]!,
                        style:
                        TextStyle(
                          color: _rowSuccess[
                          itemId] ==
                              true
                              ? Colors
                              .green[
                          300]
                              : Colors
                              .red[
                          300],
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mobileValue(
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
          const TextStyle(
            color:
            Colors.white30,
            fontSize: 9,
            fontWeight:
            FontWeight.w600,
          ),
        ),
        const SizedBox(
          height: 7,
        ),
        Text(
          value,
          style:
          const TextStyle(
            color:
            Colors.white70,
            fontSize: 14,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() =>
      _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState
    extends State<BarcodeScannerDialog> {
  final MobileScannerController cameraController =
  MobileScannerController();

  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    if (capture.barcodes.isEmpty) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;

      if (code != null && code.trim().isNotEmpty) {
        _isProcessing = true;

        Navigator.of(context).pop(code.trim());

        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final scannerWidth = screenWidth < 600
        ? screenWidth - 40
        : 500.0;

    return Container(
      width: scannerWidth,
      constraints: const BoxConstraints(
        maxWidth: 500,
        maxHeight: 650,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111E2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------------------------------------------------------
          // Header
          // ---------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white70,
                  size: 21,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Text(
                    'Scan Barcode / QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // Scanner
          // ---------------------------------------------------------
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                ),

                // Dark overlay
                IgnorePointer(
                  child: CustomPaint(
                    painter: ScannerOverlayPainter(),
                  ),
                ),

                // Scanner frame
                Center(
                  child: Container(
                    width: scannerWidth * .65,
                    height: scannerWidth * .65,
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                      maxHeight: 300,
                      minWidth: 200,
                      minHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.greenAccent,
                        width: 2.5,
                      ),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Instructions
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.65),
                      borderRadius:
                      BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Position the barcode or QR code inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // Camera controls
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                ValueListenableBuilder(
                  valueListenable: cameraController,
                  builder: (
                      context,
                      MobileScannerState state,
                      child,
                      ) {
                    final flashOn =
                        state.torchState == TorchState.on;

                    return IconButton(
                      tooltip: flashOn
                          ? 'Turn flash off'
                          : 'Turn flash on',
                      icon: Icon(
                        flashOn
                            ? Icons.flash_on
                            : Icons.flash_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        cameraController.toggleTorch();
                      },
                    );
                  },
                ),

                const SizedBox(width: 20),

                IconButton(
                  tooltip: 'Switch camera',
                  icon: const Icon(
                    Icons.cameraswitch,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    cameraController.switchCamera();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(.35);

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}




