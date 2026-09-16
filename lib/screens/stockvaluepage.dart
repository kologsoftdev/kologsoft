import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class StockValuePage extends StatefulWidget {
  const StockValuePage({super.key});

  @override
  State<StockValuePage> createState() => _StockValuePageState();
}

class _StockValuePageState extends State<StockValuePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _searchController =
  TextEditingController();

  bool _loading = true;

  String _companyId = '';
  String _selectedBranch = 'ALL';

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  List<String> _branches = [];

  double _totalStockValue = 0;
  double _totalPieces = 0;

  // ------------------------------------------------------------
  // DARK THEME
  // ------------------------------------------------------------

  static const Color backgroundColor = Color(0xFF101624);
  static const Color cardColor = Color(0xFF182232);
  static const Color inputColor = Color(0xFF22304A);
  static const Color primaryColor = Color(0xFF2F80ED);
  static const Color greenColor = Color(0xFF27AE60);

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD ITEMS
  // ------------------------------------------------------------

  Future<void> _loadItems() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final datafeed = context.read<Datafeed>();

      await datafeed.getdata();

      final companyId = datafeed.companyid.trim();

      if (companyId.isEmpty) {
        throw Exception('Company ID is empty.');
      }

      _companyId = companyId;

      final snapshot = await _db
          .collection('itemsreg')
          .where('companyid', isEqualTo: companyId)
          .get();

      final List<Map<String, dynamic>> items = [];

      final Set<String> branchSet = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final Map<String, dynamic> item = {
          ...data,
          '_docId': doc.id,
        };

        items.add(item);

        // --------------------------------------------------------
        // COLLECT BRANCHES FROM branchbalance
        // --------------------------------------------------------

        final branchBalance = data['branchbalance'];

        if (branchBalance is Map) {
          for (final entry in branchBalance.entries) {
            final branchId = entry.key.toString().trim();

            if (branchId.isNotEmpty) {
              branchSet.add(branchId);
            }
          }
        }
      }

      final branches = branchSet.toList();

      branches.sort();

      if (!mounted) return;

      setState(() {
        _allItems = items;
        _branches = branches;
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading stock value: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showSnack(
        'Failed to load stock value: $e',
        Colors.red,
      );
    }
  }

  // ------------------------------------------------------------
  // NUMBER CONVERSION
  // ------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }

  // ------------------------------------------------------------
  // COST PRICE
  // ------------------------------------------------------------

  double _getCostPrice(Map<String, dynamic> item) {
    return _toDouble(
      item['cp'] ??
          item['costprice'] ??
          item['costPrice'] ??
          item['cost_price'],
    );
  }

  // ------------------------------------------------------------
  // BRANCH BALANCE
  // ------------------------------------------------------------

  Map<String, dynamic> _getBranchBalance(
      Map<String, dynamic> item,
      String branchId,
      ) {
    final branchBalance = item['branchbalance'];

    if (branchBalance is! Map) {
      return {};
    }

    final branch = branchBalance[branchId];

    if (branch is Map) {
      return Map<String, dynamic>.from(branch);
    }

    return {};
  }

  // ------------------------------------------------------------
  // GET NET PIECES
  // ------------------------------------------------------------

  double _getNetPieces(
      Map<String, dynamic> item,
      String branchId,
      ) {
    final branch = _getBranchBalance(
      item,
      branchId,
    );

    return _toDouble(
      branch['netpieces'],
    );
  }

  // ------------------------------------------------------------
  // ITEM VALUE FOR SELECTED BRANCH
  // ------------------------------------------------------------

  double _getItemValue(
      Map<String, dynamic> item,
      ) {
    final cp = _getCostPrice(item);

    // ----------------------------------------------------------
    // SPECIFIC BRANCH
    // ----------------------------------------------------------

    if (_selectedBranch != 'ALL') {
      final netPieces = _getNetPieces(
        item,
        _selectedBranch,
      );

      return netPieces * cp;
    }

    // ----------------------------------------------------------
    // ALL BRANCHES
    // ----------------------------------------------------------

    final branchBalance = item['branchbalance'];

    if (branchBalance is! Map) {
      return 0;
    }

    double total = 0;

    for (final entry in branchBalance.entries) {
      final branch = entry.value;

      if (branch is! Map) {
        continue;
      }

      final netPieces = _toDouble(
        branch['netpieces'],
      );

      total += netPieces * cp;
    }

    return total;
  }

  // ------------------------------------------------------------
  // ITEM PIECES FOR SELECTED BRANCH
  // ------------------------------------------------------------

  double _getItemPieces(
      Map<String, dynamic> item,
      ) {
    if (_selectedBranch != 'ALL') {
      return _getNetPieces(
        item,
        _selectedBranch,
      );
    }

    final branchBalance = item['branchbalance'];

    if (branchBalance is! Map) {
      return 0;
    }

    double total = 0;

    for (final entry in branchBalance.entries) {
      final branch = entry.value;

      if (branch is! Map) {
        continue;
      }

      total += _toDouble(
        branch['netpieces'],
      );
    }

    return total;
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  void _applyFilters() {
    final search = _searchController.text
        .trim()
        .toLowerCase();

    List<Map<String, dynamic>> result =
    List<Map<String, dynamic>>.from(_allItems);

    if (search.isNotEmpty) {
      result = result.where((item) {
        final name = (item['name'] ?? '')
            .toString()
            .toLowerCase();

        final barcode = (item['barcode'] ?? '')
            .toString()
            .toLowerCase();

        final id = (item['id'] ?? '')
            .toString()
            .toLowerCase();

        final docId = (item['_docId'] ?? '')
            .toString()
            .toLowerCase();

        final category = (item['pcategory'] ?? '')
            .toString()
            .toLowerCase();

        final productType = (item['producttype'] ?? '')
            .toString()
            .toLowerCase();

        return name.contains(search) ||
            barcode.contains(search) ||
            id.contains(search) ||
            docId.contains(search) ||
            category.contains(search) ||
            productType.contains(search);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _filteredItems = result;
    });

    _calculateTotals(result);
  }

  // ------------------------------------------------------------
  // TOTALS
  // ------------------------------------------------------------

  void _calculateTotals(
      List<Map<String, dynamic>> items,
      ) {
    double value = 0;
    double pieces = 0;

    for (final item in items) {
      value += _getItemValue(item);
      pieces += _getItemPieces(item);
    }

    if (!mounted) return;

    setState(() {
      _totalStockValue = value;
      _totalPieces = pieces;
    });
  }

  // ------------------------------------------------------------
  // FORMAT MONEY
  // ------------------------------------------------------------

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  String _pieces(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ------------------------------------------------------------
  // BRANCH NAME
  // ------------------------------------------------------------

  String _branchName(
      Map<String, dynamic> item,
      String branchId,
      ) {
    final branch = _getBranchBalance(
      item,
      branchId,
    );

    final name = branch['name'];

    if (name != null &&
        name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    return branchId;
  }

  // ------------------------------------------------------------
  // SNACKBAR
  // ------------------------------------------------------------

  void _showSnack(
      String message,
      Color color,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: primaryColor,
            size: 27,
          ),
        ),

        const SizedBox(width: 14),

        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Value',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Current inventory value based on cost price',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _loadItems,
          icon: const Icon(
            Icons.refresh,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // SEARCH + BRANCH
  // ------------------------------------------------------------

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(.06),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 700;

          final search = TextField(
            controller: _searchController,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText:
              'Search item, barcode, category...',
              hintStyle: const TextStyle(
                color: Colors.white38,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
              ),
              suffixIcon:
              _searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(
                  Icons.clear,
                  color: Colors.white54,
                ),
              ),
              filled: true,
              fillColor: inputColor,
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );

          final branch = _buildBranchDropdown();

          if (compact) {
            return Column(
              children: [
                search,
                const SizedBox(height: 12),
                branch,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: search,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: branch,
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // BRANCH DROPDOWN
  // ------------------------------------------------------------

  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBranch,
      dropdownColor: cardColor,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: 'Branch',
        labelStyle: const TextStyle(
          color: Colors.white60,
        ),
        prefixIcon: const Icon(
          Icons.store_outlined,
          color: Colors.white54,
        ),
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: 'ALL',
          child: Text(
            'All Branches',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),

        ..._branches.map(
              (branchId) {
            return DropdownMenuItem<String>(
              value: branchId,
              child: Text(
                branchId,
                style: const TextStyle(
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedBranch = value;
        });

        _calculateTotals(
          _filteredItems,
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SUMMARY CARDS
  // ------------------------------------------------------------

  Widget _buildSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 700;

        final cards = [
          _summaryCard(
            title: 'Stock Value',
            value: _money(_totalStockValue),
            icon: Icons.account_balance_wallet_outlined,
            iconColor: greenColor,
          ),

          _summaryCard(
            title: 'Net Pieces',
            value: _pieces(_totalPieces),
            icon: Icons.inventory_outlined,
            iconColor: primaryColor,
          ),

          _summaryCard(
            title: 'Items',
            value: _filteredItems.length.toString(),
            icon: Icons.category_outlined,
            iconColor: Colors.orange,
          ),

          _summaryCard(
            title: 'Branch',
            value: _selectedBranch == 'ALL'
                ? 'All'
                : _selectedBranch,
            icon: Icons.store_outlined,
            iconColor: Colors.purpleAccent,
          ),
        ];

        if (compact) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: cards,
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1)
                const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DESKTOP TABLE
  // ------------------------------------------------------------

  Widget _buildDesktopTable() {
    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 1000,
            ),
            child: DataTable(
              headingRowColor:
              WidgetStateProperty.all(
                inputColor,
              ),
              dataRowMinHeight: 62,
              dataRowMaxHeight: 72,
              columnSpacing: 25,

              columns: const [
                DataColumn(
                  label: Text(
                    '#',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ITEM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'BARCODE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CATEGORY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'CP',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'NET PIECES',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'STOCK VALUE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              rows: List.generate(
                _filteredItems.length,
                    (index) {
                  final item =
                  _filteredItems[index];

                  final cp =
                  _getCostPrice(item);

                  final pieces =
                  _getItemPieces(item);

                  final value =
                  _getItemValue(item);

                  final name =
                  (item['name'] ?? '-')
                      .toString();

                  final barcode =
                  (item['barcode'] ?? '-')
                      .toString();

                  final category =
                  (item['pcategory'] ?? '-')
                      .toString();

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${index + 1}',
                          style:
                          const TextStyle(
                            color: Colors.white54,
                          ),
                        ),
                      ),

                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              color: Colors.white,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          barcode,
                          style:
                          const TextStyle(
                            color: Colors.white60,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          category,
                          style:
                          const TextStyle(
                            color: Colors.white60,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          _money(cp),
                          style:
                          const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          _pieces(pieces),
                          style:
                          const TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          _money(value),
                          style:
                          const TextStyle(
                            color: greenColor,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // MOBILE
  // ------------------------------------------------------------

  Widget _buildMobileList() {
    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item =
        _filteredItems[index];

        final cp =
        _getCostPrice(item);

        final pieces =
        _getItemPieces(item);

        final value =
        _getItemValue(item);

        final name =
        (item['name'] ?? '-').toString();

        final barcode =
        (item['barcode'] ?? '-').toString();

        final category =
        (item['pcategory'] ?? '-').toString();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius:
            BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(.06),
            ),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                      primaryColor.withOpacity(.12),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style:
                        const TextStyle(
                          color: primaryColor,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                barcode,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                category,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),

              const Divider(
                height: 22,
                color: Colors.white10,
              ),

              Row(
                children: [
                  Expanded(
                    child: _mobileValue(
                      'CP',
                      _money(cp),
                    ),
                  ),

                  Expanded(
                    child: _mobileValue(
                      'NET PIECES',
                      _pieces(pieces),
                    ),
                  ),

                  Expanded(
                    child: _mobileValue(
                      'VALUE',
                      _money(value),
                      valueColor:
                      greenColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileValue(
      String title,
      String value, {
        Color valueColor = Colors.white,
      }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // EMPTY
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 70,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            _searchController.text.isNotEmpty
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 50,
            color: Colors.white24,
          ),
          const SizedBox(height: 15),
          Text(
            _searchController.text.isNotEmpty
                ? 'No items found'
                : 'No stock items found',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LOADING
  // ------------------------------------------------------------

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(80),
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'Stock Value',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile =
                constraints.maxWidth < 750;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                isMobile ? 12 : 24,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 22),

                  _buildFilters(),

                  const SizedBox(height: 16),

                  if (_loading)
                    _buildLoading()
                  else ...[
                    _buildSummary(),

                    const SizedBox(height: 18),

                    if (isMobile)
                      _buildMobileList()
                    else
                      _buildDesktopTable(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}