import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/itemregmodel.dart';

class SyncItemtoZero extends StatefulWidget {
  const SyncItemtoZero({super.key});

  @override
  State<SyncItemtoZero> createState() => _SyncItemtoZeroState();
}

class _SyncItemtoZeroState extends State<SyncItemtoZero> {
  // ── Single-item fields
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  ItemModel? _selectedItem;
  bool _showSuggestions = false;
  bool _selecting = false;
  bool _selectedItemOrphaned = false;
  bool _checkingOrphan = false;
  int _orphanCheckToken = 0;

  // ── Shared fields
  String? _selectedBranchId;
  String? _selectedBranchName;
  bool _syncing = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  // tab: 0 = single item, 1 = all items in branch
  int _tab = 0;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  final List<String> _bulkLog = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchstockreport();
      if (!mounted) return;
      _searchController.addListener(_onSearchChanged);
    });
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_selecting) return;
    setState(() {
      _showSuggestions = _searchController.text.isNotEmpty;
      _selectedItem = null;
      _selectedItemOrphaned = false;
      _resultMessage = null;
    });
  }

  void _selectItem(ItemModel item) {
    _selecting = true;
    setState(() {
      _selectedItem = item;
      _searchController.text = item.name;
      _showSuggestions = false;
      _resultMessage = null;
    });
    _selecting = false;
    _searchFocus.unfocus();
    _refreshOrphanStatus();
  }

  Future<Set<String>> _fetchBranchStockReportItemIds(String branchId) async {
    final provider = context.read<Datafeed>();
    await provider.fetchstockreport(
      selectedDate: DateTimeRange(
        start: DateTime(2000, 1, 1),
        end: DateTime.now(),
      ),
      selectedBranch: branchId,
    );
    final stockreport = provider.filterstockreport();
    return stockreport
        .where((e) => (e['itemid'] ?? '').toString().isNotEmpty)
        .map((e) => e['itemid'].toString())
        .toSet();
  }

  Future<void> _refreshOrphanStatus() async {
    if (_selectedItem == null || _selectedBranchId == null) {
      setState(() => _selectedItemOrphaned = false);
      return;
    }
    final hasBranchBalance = _selectedItem!.branchbalance != null &&
        _selectedItem!.branchbalance!.containsKey(_selectedBranchId);
    if (!hasBranchBalance) {
      setState(() => _selectedItemOrphaned = false);
      return;
    }
    final token = ++_orphanCheckToken;
    setState(() => _checkingOrphan = true);
    final ids = await _fetchBranchStockReportItemIds(_selectedBranchId!);
    if (!mounted || token != _orphanCheckToken) return;
    setState(() {
      _selectedItemOrphaned = !ids.contains(_selectedItem!.id);
      _checkingOrphan = false;
    });
  }

  // Single item sync
  Future<void> _syncBalance() async {
    if (_selectedItem == null || _selectedBranchId == null) return;
    setState(() { _syncing = true; _resultMessage = null; });
    try {
      final provider = context.read<Datafeed>();
      num balance;
      if (_selectedItemOrphaned) {
        balance = 0;
      } else {
        balance = await provider.fetchItemCurrentBalance(
          itemId: _selectedItem!.id,
          selectedBranch: _selectedBranchId,
        ) ?? 0;
      }
      await provider.db
          .collection('itemsreg')
          .doc(_selectedItem!.id)
          .update({
        'branchbalance.$_selectedBranchId.netpieces': balance,
        'branchbalance.$_selectedBranchId.lastupdate':
        FieldValue.serverTimestamp(),
      });
      setState(() {
        _resultMessage = _selectedItemOrphaned
            ? 'Synced  ${_selectedItem!.name}  →  $_selectedBranchName  |  Reset to 0 pcs (not in stock report)'
            : 'Synced  ${_selectedItem!.name}  →  $_selectedBranchName  |  $balance pcs';
        _resultSuccess = true;
      });
    } catch (e) {
      setState(() { _resultMessage = 'Error: $e'; _resultSuccess = false; });
    } finally {
      setState(() => _syncing = false);
    }
  }

  //Bulk sync: all items in selected branch

  Future<void> _syncAllItems() async {
    if (_selectedBranchId == null) return;

    final provider = context.read<Datafeed>();

    setState(() {
      _syncing = true;
      _bulkDone = 0;
      _bulkTotal = 0;
      _bulkLog.clear();
      _resultMessage = null;
    });

    try {
      // Build stock report for the selected branch
      await provider.fetchstockreport(
        selectedDate: DateTimeRange(
          start: DateTime(2000, 1, 1),
          end: DateTime.now(),
        ),
        selectedBranch: _selectedBranchId,
      );

      final stockreport = provider.filterstockreport();
      final items = stockreport
          .where((e) => (e['itemid'] ?? '').toString().isNotEmpty)
          .toList();
      print(items.length);

      final stockItemIds = items.map((e) => e['itemid'].toString()).toSet();

      final orphanedItems = provider.items.where((i) =>
      i.isActive == true &&
          i.branchbalance != null &&
          i.branchbalance!.containsKey(_selectedBranchId) &&
          !stockItemIds.contains(i.id)).toList();

      if (items.isEmpty && orphanedItems.isEmpty) {
        setState(() {
          _syncing = false;
          _resultSuccess = false;
          _resultMessage =
          'No stock report items found for $_selectedBranchName.';
        });
        return;
      }

      setState(() {
        _bulkTotal = items.length + orphanedItems.length;
      });

      int successCount = 0;
      int errorCount = 0;

      for (final row in items) {
        final itemId = row['itemid'].toString();
        final itemName = row['item']?.toString() ?? itemId;
        final balance = (row['balance_cd'] ?? 0);

        try {
          await provider.db
              .collection('itemsreg')
              .doc(itemId)
              .set({
            'branchbalance': {
              _selectedBranchId: {
                'netpieces': balance,
                'lastupdate': FieldValue.serverTimestamp(),
              }
            }
          }, SetOptions(merge: true));

          _bulkLog.add('✓ $itemName → $balance pcs');
          successCount++;
        } catch (e) {
          _bulkLog.add('✗ $itemName → Error: $e');
          errorCount++;
        }

        if (mounted) {
          setState(() => _bulkDone++);
        }
      }

      for (final item in orphanedItems) {
        try {
          await provider.db
              .collection('itemsreg')
              .doc(item.id)
              .set({
            'branchbalance': {
              _selectedBranchId: {
                'netpieces': 0,
                'lastupdate': FieldValue.serverTimestamp(),
              }
            }
          }, SetOptions(merge: true));

          _bulkLog.add('⊘ ${item.name} → 0 pcs (not in stock report)');
          successCount++;
        } catch (e) {
          _bulkLog.add('✗ ${item.name} → Error: $e');
          errorCount++;
        }

        if (mounted) {
          setState(() => _bulkDone++);
        }
      }

      setState(() {
        _syncing = false;
        _resultSuccess = errorCount == 0;
        _resultMessage =
        'Done: $successCount synced${errorCount > 0 ? ', $errorCount failed' : ''} — $_selectedBranchName';
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _resultSuccess = false;
        _resultMessage = 'Error syncing items: $e';
      });
    }
  }
  //UI helpers
  static const _inputFill = Color(0xFF1B2A3E);
  static const _cardBg    = Color(0xFF162032);

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
    filled: true,
    fillColor: _inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF3B8BEB), width: 1.5),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        )),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1826),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111E2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text('Sync Branch Balance',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white12, height: 1),
        ),
      ),
      body: Consumer<Datafeed>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 640;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A5C).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF3B8BEB).withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.sync_alt,
                                color: Color(0xFF3B8BEB), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sync a single item or all items in a branch.',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 12),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        //Tab toggle
                        Container(
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(children: [
                            _tabBtn('Single Item', 0),
                            const SizedBox(width: 6),
                            _tabBtn('All Items in Branch', 1),
                          ]),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('BRANCH'),
                              DropdownButtonFormField<String>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1B2A3E),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white38),
                                decoration: _dec('Select branch…'),
                                items: provider.branches
                                    .fold<Map<String, dynamic>>({}, (m, b) {
                                  if (b.id != null &&
                                      b.id!.isNotEmpty &&
                                      !m.containsKey(b.id)) m[b.id!] = b;
                                  return m;
                                })
                                    .values
                                    .map((b) => DropdownMenuItem<String>(
                                  value: b.id as String,
                                  child: Text(b.branchname as String,
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ))
                                    .toList(),
                                onChanged: _syncing
                                    ? null
                                    : (val) {
                                  final branch = provider.branches
                                      .firstWhere((b) => b.id == val);
                                  setState(() {
                                    _selectedBranchId   = val;
                                    _selectedBranchName = branch.branchname;
                                    _resultMessage      = null;
                                    _bulkLog.clear();
                                    _bulkDone  = 0;
                                    _bulkTotal = 0;
                                  });
                                  // Auto-trigger sync based on current tab
                                  if (_tab == 0) {
                                    _refreshOrphanStatus();
                                  } else if (_tab == 1) {
                                    // All items tab: auto-start sync
                                    _syncAllItems();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_tab == 0) ...[
                          _buildSingleItemCard(provider),
                        ] else ...[
                          _buildBulkInfoCard(provider),
                        ],

                        const SizedBox(height: 14),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _canSync(provider) ? _onSync : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B8BEB),
                              disabledBackgroundColor:
                              const Color(0xFF3B8BEB).withOpacity(0.25),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: _syncing
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.sync,
                                color: Colors.white, size: 18),
                            label: Text(
                              _syncing
                                  ? (_tab == 1
                                  ? 'Syncing $_bulkDone / $_bulkTotal…'
                                  : 'Saving…')
                                  : (_tab == 1
                                  ? 'Sync All Items in Branch'
                                  : 'Save Balance Update'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                            ),
                          ),
                        ),

                        if (_tab == 1 && _syncing && _bulkTotal > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _bulkDone / _bulkTotal,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF3B8BEB)),
                            ),
                          ),
                        ],

                        if (_resultMessage != null) ...[
                          const SizedBox(height: 14),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _resultSuccess
                                  ? Colors.green.withOpacity(0.08)
                                  : Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _resultSuccess
                                    ? Colors.green.withOpacity(0.35)
                                    : Colors.red.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _resultSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: _resultSuccess
                                      ? Colors.green
                                      : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _resultMessage!,
                                    style: TextStyle(
                                      color: _resultSuccess
                                          ? Colors.green[300]
                                          : Colors.red[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_tab == 1 && _bulkLog.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 240),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111E2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemCount: _bulkLog.length,
                              itemBuilder: (_, i) => Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  _bulkLog[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _bulkLog[i].startsWith('✓')
                                        ? Colors.green[300]
                                        : _bulkLog[i].startsWith('⊘')
                                        ? Colors.orange[300]
                                        : Colors.red[300],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: _syncing
            ? null
            : () => setState(() {
          _tab           = index;
          _resultMessage = null;
          _bulkLog.clear();
          _bulkDone  = 0;
          _bulkTotal = 0;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3B8BEB).withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF3B8BEB).withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFF3B8BEB) : Colors.white38,
              fontSize: 12,
              fontWeight:
              active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleItemCard(Datafeed provider) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('ITEM'),
          TextFormField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onTap: () {
              if (_searchController.text.isNotEmpty) {
                setState(() => _showSuggestions = true);
              }
            },
            decoration: _dec(
              'Search by name or barcode',
              suffix: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white38, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedItem  = null;
                    _selectedItemOrphaned = false;
                    _showSuggestions = false;
                    _resultMessage = null;
                  });
                },
              )
                  : const Icon(Icons.search,
                  color: Colors.white24, size: 18),
            ),
          ),

          // selected chip
          if (_selectedItem != null && !_showSuggestions) ...[
            const SizedBox(height: 10),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B8BEB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF3B8BEB).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF3B8BEB), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedItem!.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  _selectedItem!.barcode,
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ]),
            ),
            if (_checkingOrphan) ...[
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white38),
                ),
                const SizedBox(width: 8),
                Text('Checking stock report…',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ]),
            ] else if (_selectedItemOrphaned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Not found in stock report for $_selectedBranchName. Balance will be reset to 0.',
                      style: TextStyle(
                          color: Colors.orange[300], fontSize: 11),
                    ),
                  ),
                ]),
              ),
            ],
          ],

          // suggestions
          if (_showSuggestions) ...[
            const SizedBox(height: 6),
            _buildSuggestions(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkInfoCard(Datafeed provider) {
    if (_selectedBranchId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'Select a branch above to see how many items will be synced.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final eligible = provider.items
        .where((i) => i.isActive == true)
        .where((i) =>
    i.branchbalance != null &&
        i.branchbalance!.containsKey(_selectedBranchId))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.info_outline,
                color: Color(0xFF3B8BEB), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${eligible.length} item${eligible.length == 1 ? '' : 's'} will be synced for $_selectedBranchName.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ]),
          if (eligible.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            // preview list (first 5)
            ...eligible.take(5).map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.white24, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(i.name,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ),
              ]),
            )),
            if (eligible.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${eligible.length - 5} more…',
                  style: const TextStyle(
                      color: Colors.white30, fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }
  Widget _buildSuggestions(Datafeed provider) {
    final query    = _searchController.text.toLowerCase();
    final filtered = provider.items
        .where((i) => i.isActive == true)
        .where((i) =>
    i.name.toLowerCase().contains(query) ||
        i.barcode.toLowerCase().contains(query) ||
        i.pcategory.toLowerCase().contains(query))
        .take(10)
        .toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('No items found for "$query"',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF111E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF3B8BEB).withOpacity(0.2)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final bb   = item.branchbalance;
          final branchPieces = _selectedBranchId != null && bb != null
              ? (bb[_selectedBranchId] as Map<String, dynamic>?) != null ? (bb[_selectedBranchId] as Map<String, dynamic>?)!['netpieces'] : null
              : null;

          return ListTile(
            dense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B8BEB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF3B8BEB), size: 16),
            ),
            title: Text(item.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            subtitle: Text(
              '${item.pcategory}  ·  ${item.barcode}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: branchPieces != null
                ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$branchPieces pcs',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            )
                : const Icon(Icons.chevron_right,
                color: Colors.white24, size: 16),
            onTap: () => _selectItem(item),
          );
        },
      ),
    );
  }

  // Helpers
  bool _canSync(Datafeed provider) {
    if (_syncing || _selectedBranchId == null) return false;
    if (_tab == 0) return _selectedItem != null;
    // tab 1: need at least one eligible item
    return provider.items.any((i) =>
    i.isActive == true &&
        i.branchbalance != null &&
        i.branchbalance!.containsKey(_selectedBranchId));
  }

  void _onSync() {
    if (_tab == 0) {
      _syncBalance();
    } else {
      _syncAllItems();
    }
  }
}