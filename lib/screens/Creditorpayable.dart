

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import 'Creditorpayablelist.dart';


class _C {
  static const bg        = Color(0xFF101A23);
  static const surface   = Color(0xFF1A1D27);
  static const card      = Color(0xFF22304A);
  static const header    = Color(0xFF0D1A26);
  static const divider   = Color(0xFF2C2F3E);
  static const primary   = Color(0xFF3B82F6);
  static const positive  = Color(0xFF22C55E);
  static const negative  = Color(0xFFEF4444);
  static const warning   = Color(0xFFF59E0B);
  static const textPri   = Color(0xFFE2E8F0);
  static const textSub   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF4B5563);
}


//Main screen
class CreditorPayableScreen extends StatefulWidget {
  final String?selectedBranch;
  final String?docId;
  final CreditorBalance? creditinfo;
  const CreditorPayableScreen({Key? key, this.docId, this.creditinfo, this.selectedBranch})
      : super(key: key);

  @override
  State<CreditorPayableScreen> createState() => _CreditorPayableScreenState();
}

class _CreditorPayableScreenState extends State<CreditorPayableScreen> {
  final _searchCtrl    = TextEditingController();
  int?  _sortColumnIndex;
  bool  _sortAscending = true;
  String? _selectedBranch;
  int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      context.read<Datafeed>().fetchPaymentMethods();
      _selectedBranch = datafeed.selectedBranch?.id ?? '';
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchCreditorlist();
    });

    _searchCtrl.addListener(() {
      if (!mounted) return;
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      datafeed.searchQuery = _searchCtrl.text;
      datafeed.notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 800;
  void _openPaymentDialog(Map<String, dynamic> creditor) {
    showDialog(
      context: context,
      builder: (_) => _CreditorPaymentDialog(
        creditorId:     creditor['creditorId'] ?? '',
        creditorName:   creditor['name']       ?? '',
        balance:        (creditor['balance']   ?? 0).toString(),
        selectedBranch: _selectedBranch!,
        creditinfo:     widget.creditinfo,
      ),
    );
  }

  // Mobile list
  Widget _mobileList(List<Map<String, dynamic>> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c       = rows[i];
        final name    = c['name']    ?? '';
        final debit   = (c['debit']   as num?)?.toDouble() ?? 0.0;
        final credit  = (c['credit']  as num?)?.toDouble() ?? 0.0;
        final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
        final isOwed  = balance > 0;

        return Material(
          color: _C.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openPaymentDialog(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: index, name, chevron
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                color: _C.textPri, fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: _C.textMuted, size: 18),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Bottom row: debit/credit + balance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AmountChip('Debit: GHS ${NumberFormat('#,##0.00').format(debit)}',  _C.textPri),
                            const SizedBox(height: 4),
                            _AmountChip('Credit: GHS ${NumberFormat('#,##0.00').format(credit)}', _C.textPri),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _BalanceChip(balance, isOwed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  //Desktop table — sorting helpers
  List<Map<String, dynamic>> _sortRows(List<Map<String, dynamic>> rows) {
    final sorted = List<Map<String, dynamic>>.from(rows);
    if (_sortColumnIndex == null) return sorted;

    sorted.sort((a, b) {
      dynamic av, bv;
      switch (_sortColumnIndex) {
        case 1:
          av = (a['name'] ?? '').toString();
          bv = (b['name'] ?? '').toString();
          break;
        case 2:
          av = (a['debit'] as num?)?.toDouble() ?? 0.0;
          bv = (b['debit'] as num?)?.toDouble() ?? 0.0;
          break;
        case 3:
          av = (a['credit'] as num?)?.toDouble() ?? 0.0;
          bv = (b['credit'] as num?)?.toDouble() ?? 0.0;
          break;
        case 4:
          av = (a['balance'] as num?)?.toDouble() ?? 0.0;
          bv = (b['balance'] as num?)?.toDouble() ?? 0.0;
          break;
        default:
          return 0;
      }
      final cmp = Comparable.compare(av as Comparable, bv as Comparable);
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _currentPage = 0;
    });
  }

  Widget _headerCell(String label, {int? columnIndex, bool numeric = false}) {
    final isSorted = columnIndex != null && _sortColumnIndex == columnIndex;
    return InkWell(
      onTap: columnIndex == null ? null : () => _onSort(columnIndex),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
        numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: _C.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5),
          ),
          if (columnIndex != null) ...[
            const SizedBox(width: 2),
            Icon(
              isSorted
                  ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isSorted ? _C.primary : _C.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopTable(double width, List<Map<String, dynamic>> rows, Datafeed datafeed) {
    final sortedRows = _sortRows(rows);

    final totalRows = sortedRows.length;
    final totalPages = totalRows == 0 ? 1 : (totalRows / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, totalPages - 1);

    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, totalRows);
    final pageRows = totalRows == 0 ? <Map<String, dynamic>>[] : sortedRows.sublist(start, end);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          // Header row
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFF161B2D),
            child: Row(
              children: [
                const SizedBox(width: 32, child: Text('#', style: TextStyle(color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _headerCell('Name', columnIndex: 1)),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('Debit', columnIndex: 2, numeric: true))),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('Credit', columnIndex: 3, numeric: true))),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('Balance', columnIndex: 4, numeric: true))),
                const SizedBox(width: 16),
                const SizedBox(width: 90, child: Text('Action', style: TextStyle(color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          Container(height: 1, color: _C.divider),

          // Rows
          Expanded(
            child: pageRows.isEmpty
                ? const SizedBox()
                : ListView.builder(
              itemCount: pageRows.length,
              itemBuilder: (context, i) {
                final c = pageRows[i];
                final globalIndex = start + i;
                final name = c['name'] ?? '';
                final debit = (c['debit'] as num?)?.toDouble() ?? 0.0;
                final credit = (c['credit'] as num?)?.toDouble() ?? 0.0;
                final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
                final isOwed = balance > 0;

                return Material(
                  color: _C.card,
                  child: InkWell(
                    onTap: () => _openPaymentDialog(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _C.divider, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text('${globalIndex + 1}',
                                style: const TextStyle(color: _C.textPri, fontSize: 12)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(name,
                                style: const TextStyle(
                                    color: _C.textPri, fontWeight: FontWeight.w500, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              debit > 0 ? NumberFormat('#,##0.00').format(debit) : '0.00',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: _C.textPri, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              credit > 0 ? NumberFormat('#,##0.00').format(credit) : '0.00',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: _C.textPri, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _BalanceChip(balance, isOwed),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 90,
                            child: TextButton(
                              onPressed: () => _openPaymentDialog(c),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: _C.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Pay',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(height: 1, color: _C.divider),

          // Pagination footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows per page: ', style: TextStyle(color: _C.textSub, fontSize: 12)),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      dropdownColor: _C.card,
                      style: const TextStyle(color: _C.textPri, fontSize: 12),
                      underline: const SizedBox(),
                      items: const [10, 25, 50, 100]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _rowsPerPage = v;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      totalRows == 0
                          ? '0–0 of 0'
                          : '${start + 1}–$end of $totalRows',
                      style: const TextStyle(color: _C.textSub, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: _C.textSub, size: 20),
                      onPressed: safePage > 0
                          ? () => setState(() => _currentPage = safePage - 1)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: _C.textSub, size: 20),
                      onPressed: (safePage + 1) < totalPages
                          ? () => setState(() => _currentPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        final rows      = datafeed.filterCreditorlist();
        final isLoading = datafeed.isLoadingcreditlist;

        return Scaffold(
          backgroundColor: _C.bg,
          appBar: AppBar(
            backgroundColor: _C.header,
            elevation:       0,
            titleSpacing:    0,
            leading: const BackButton(color: _C.textPri),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('List of Creditors',
                    style: TextStyle(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Manage your creditors and track payables',
                    style: TextStyle(color: _C.textSub, fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:  _C.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _C.primary.withOpacity(0.25), width: 1),
                    ),
                    child: Text(datafeed.company,
                        style: const TextStyle(
                            color: _C.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _C.divider),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    const SizedBox(height: 14),

                    // Branch dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String?>(
                        value: () {
                          final id = datafeed.selectedBranch?.id;
                          final exists = datafeed.branches
                              .where((b) => b.branchtype != 'Warehouse')
                              .any((b) => b.id == id);
                          return exists ? id : null;
                        }(),
                        dropdownColor: const Color(0xFF22304A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Select Branch',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue)),
                          fillColor: const Color(0xFF22304A),
                          filled: true,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Branches', style: TextStyle(color: Colors.white70)),
                          ),
                          // Deduplicate by id before mapping
                          ...datafeed.branches
                              .where((b) => b.branchtype != 'Warehouse')
                              .fold<List<dynamic>>([], (list, b) {
                            if (!list.any((x) => x.id == b.id)) list.add(b);
                            return list;
                          })
                              .map((b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(b.branchname),
                          )),
                        ],
                        onChanged: (val) {
                          _selectedBranch = val;
                          datafeed.fetchCreditorlist(branchID: val);
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Search bar
                    Container(
                      // color: _C.textMuted,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(color: _C.textPri, fontSize: 14),
                              decoration: InputDecoration(
                                hintText:   'Search creditor name…',
                                hintStyle:  const TextStyle(color: _C.textMuted, fontSize: 13),
                                prefixIcon: const Icon(Icons.search, color: _C.textSub, size: 20),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                    icon: const Icon(Icons.close, color: _C.textSub, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      datafeed.searchQuery = '';
                                      datafeed.notifyListeners();
                                    })
                                    : null,
                                filled:         true,
                                fillColor:      _C.card,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: _C.primary, width: 1.5)),
                              ),
                            ),
                          ),
                          if (!_isMobile) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                  color: _C.card, borderRadius: BorderRadius.circular(10)),
                              child: Text('${rows.length} record${rows.length == 1 ? '' : 's'}',
                                  style: const TextStyle(color: _C.textSub, fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Container(height: 1, color: _C.divider),

                    Flexible(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: _C.primary))
                          : rows.isEmpty
                          ? _buildEmptyState()
                          : LayoutBuilder(builder: (ctx, constraints) {
                        if (_isMobile) return _mobileList(rows);
                        final w = constraints.maxWidth < 900
                            ? 900.0
                            : constraints.maxWidth;
                        return _desktopTable(w, rows, datafeed);
                      }),
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

  Widget _buildEmptyState() {
    final q = _searchCtrl.text;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: _C.card, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: _C.textMuted),
          ),
          const SizedBox(height: 16),
          Text(q.isEmpty ? 'No creditors found' : 'No results for "$q"',
              style: const TextStyle(
                  color: _C.textSub, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            q.isEmpty
                ? 'Creditors will appear here once data is loaded and Branch selected.'
                : 'Try adjusting your search term.',
            style: const TextStyle(color: _C.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Payment dialog
class _CreditorPaymentDialog extends StatefulWidget {
  final String          creditorId;
  final String          creditorName;
  final String          balance;
  final String          selectedBranch;
  final CreditorBalance? creditinfo;

  const _CreditorPaymentDialog({
    required this.creditorId,
    required this.creditorName,
    required this.balance,
    required this.selectedBranch,
    this.creditinfo,
  });

  @override
  State<_CreditorPaymentDialog> createState() => _CreditorPaymentDialogState();
}

class _CreditorPaymentDialogState extends State<_CreditorPaymentDialog> {
  final _formKey       = GlobalKey<FormState>();
  final _amountCtrl    = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _narationCtrl  = TextEditingController();
  final _dateCtrl      = TextEditingController();
  final phoneController = TextEditingController();

  DateTime? _selectedDate;
  String?   _paymentMode;
  String?   _paymentAccount;
  bool      _saving = false;
  String?   selectedMomoNetwork = 'MTN';

  //payment type

  void showMessage(BuildContext context, Color color, String message) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,style: TextStyle(color: Colors.white),),
        backgroundColor: color,
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.balance;
    Future.microtask(() async {
      if (!mounted) return;
      context.read<Datafeed>().fetchPaymentMethods();
      await context.read<Datafeed>().getdata();
      if (widget.creditinfo != null) {
        final c = widget.creditinfo!;
        _referenceCtrl.text = c.transactionRef;
        _amountCtrl.text    = c.amount.toString();
        _narationCtrl.text  = c.naration ?? '';
        _dateCtrl.text = c.date != null
            ? DateFormat('yyyy-MM-dd').format(c.date!)
            : '';
        _paymentMode    = c.paymentMode;
        _paymentAccount = c.paymentaccount ?? '';
        phoneController.text = c.phone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _referenceCtrl.dispose();
    _narationCtrl.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: now,
      firstDate:   DateTime(2000),
      lastDate:    DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _C.primary, surface: _C.card),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  //Save

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_paymentMode ?? '').toLowerCase().contains('momo') &&
        (selectedMomoNetwork == null || selectedMomoNetwork!.isEmpty)) {
      showMessage(context, Colors.red, 'Please select MoMo network');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    final datafeed      = Provider.of<Datafeed>(context, listen: false);
    final amountText    = _amountCtrl.text.trim();
    final transRef      = _referenceCtrl.text.trim();
    final naration      = _narationCtrl.text.trim();
    final paymentMode   = _paymentMode ?? '';
    final payAccount    = _paymentAccount ?? '';
    final selectedDate  = _selectedDate;
    final phone         = phoneController.text.trim();
    final momoNetwork   = selectedMomoNetwork;
    final supplierid    = widget.creditorId;

    final double amount;
    try {
      amount = double.parse(amountText);
    }
    catch (_) {
      showMessage(context, Colors.red, 'Invalid amount entered');
      setState(() => _saving = false);
      return;
    }



    String sanitize(String input) => input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final ts    = DateTime.now().millisecondsSinceEpoch;
    final docId = '${sanitize(datafeed.companyid)}_${sanitize(datafeed.staffPosition.toString())}_${sanitize(widget.creditorName)}_$ts';
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final year = now.year.toString();
    final month = '${now.year}.${now.month}';
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

    final week = '${now.year}.$weekNumber';
    try {
      final creditpay = CreditorBalance(
        id: docId,
        creditorId: widget.creditorId,
        creditorName: widget.creditorName,
        amount:   amount,
        type:     'credit payment',
        paymentMode: paymentMode,
        transactionRef: transRef,
        naration:  naration,
        date:      selectedDate,
        branchid:  datafeed.branchid,
        companyid: datafeed.companyid,
        companyemail: datafeed.companyemail,
        paymentaccount: payAccount,
        phone:     phone,
        staff:     datafeed.staff,
        updatedby: '',
        updatedat: null,
        networktype: momoNetwork,
        day: day,
        week: week,
        month: month,
        yearr: year,
      );

      final batch = datafeed.db.batch();
      batch.set(
        datafeed.db.collection('creditor_payments').doc(docId),
        creditpay.toMap(),
      );
      batch.update(
        datafeed.db.collection('suppliers').doc(supplierid),
        {'debitaccount': FieldValue.increment(amount)},
      );
      await batch.commit();

      final index = datafeed.creditorList.indexWhere((item) => item['creditorId'] == supplierid);
      final indexed = datafeed.creditorpayList.indexWhere((t)=>t.id==docId);
      if(indexed == -1){
        datafeed.creditorpayList.add(creditpay);
      }
      else{
        datafeed.creditorpayList[indexed]=creditpay;
      }
      if (index != -1) {
        final creditor   = datafeed.creditorList[index];
        final newDebit   = ((creditor['debit']  ?? 0) as num) + amount;
        final credit     = ((creditor['credit'] ?? 0) as num);
        final newBalance = credit - newDebit;

        datafeed.creditorList[index] = {
          ...creditor,
          'debit':   newDebit,
          'balance': newBalance < 0.00 ? 0.00 : newBalance,
        };
        datafeed.notifyListeners();
      }

      if (!mounted) return;

      _amountCtrl.clear();
      _dateCtrl.clear();
      _referenceCtrl.clear();
      _narationCtrl.clear();
      setState(() {
        _paymentMode    = null;
        _paymentAccount = null;

      });

      showMessage(context, Colors.green, 'Payment saved successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, Colors.red, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: _C.bg,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // Header
                        Container(
                          color: _C.header,
                          padding: const EdgeInsets.fromLTRB(20, 0, 12, 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PAYABLES — ${widget.creditorName.toUpperCase()}',
                                      style: const TextStyle(
                                          color: _C.primary, fontSize: 15,
                                          fontWeight: FontWeight.w700, letterSpacing: 0.4),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Outstanding balance: ${widget.balance}',
                                      style: const TextStyle(color: _C.textSub, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: _C.textSub, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        Container(height: 1, color: _C.divider),

                        //Form body
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              //Amount
                              _FormLabel('Amount', required: true),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _amountCtrl,
                                cursorColor: Colors.white,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                style:   const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration(
                                    'Amount you are paying to ${widget.creditorName}'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                                  if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                                  if (double.parse(v.trim()) <= 0) return 'Amount must be > 0';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 5),

                              //Payment Mode
                              _FormLabel('Payment Mode', required: true),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                value: datafeed.allowedPaymentMethods.contains(_paymentMode)
                                    ? _paymentMode
                                    : null,
                                dropdownColor: _C.card,
                                style: const TextStyle(color: _C.textPri),
                                hint: const Text('Select Payment Mode',
                                    style: TextStyle(color: _C.textMuted)),
                                decoration: _fieldDecoration(null),
                                items: datafeed.allowedPaymentMethods
                                    .map((m) => DropdownMenuItem<String>(
                                    value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _paymentMode    = v;
                                  // _paymentAccount = null;
                                  final accounts = (v == null || v.isEmpty)  ? <String>[] : datafeed.getAccounts(v);
                                  if (accounts.length == 1) {
                                    _paymentAccount = accounts.first;
                                  } else {
                                    _paymentAccount = null;
                                  }
                                }),
                                validator: (v) =>
                                (v == null || v.isEmpty) ? 'Select payment mode' : null,
                              ),

                              const SizedBox(height: 5),

                              //Payment Account
                              _FormLabel('Payment Account', required: true),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                value: (_paymentAccount != null && _paymentAccount!.isNotEmpty)
                                    ? _paymentAccount
                                    : null,
                                dropdownColor: _C.card,
                                style:         const TextStyle(color: _C.textPri),
                                hint: const Text('Select account',
                                    style: TextStyle(color: _C.textMuted)),
                                decoration: _fieldDecoration(null),
                                items: (_paymentMode == null || _paymentMode!.isEmpty)
                                    ? []
                                    : datafeed
                                    .getAccounts(_paymentMode!)
                                    .map((a) => DropdownMenuItem<String>(
                                    value: a, child: Text(a)))
                                    .toList(),
                                onChanged: (_paymentMode == null || _paymentMode!.isEmpty)
                                    ? null
                                    : (v) => setState(() => _paymentAccount = v),
                                validator: (v) {
                                  if (_paymentMode == null || _paymentMode!.isEmpty) {
                                    return 'Select payment mode first';
                                  }
                                  if (v == null || v.isEmpty) return 'Select a payment account';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 5),

                              // ── MoMo extras
                              if ((_paymentMode ?? '').toLowerCase().contains('momo')) ...[
                                _FormLabel('Select Network type', required: true),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: _C.card,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:       selectedMomoNetwork,
                                      isExpanded:  true,
                                      hint: const Text('Select MOMO Network',
                                          style: TextStyle(color: Colors.white70)),
                                      dropdownColor: _C.card,
                                      style:         const TextStyle(color: Colors.white),
                                      items: ['MTN', 'Vodafone', 'AirtelTigo'].map((network) =>
                                          DropdownMenuItem<String>(
                                            value: network,
                                            child: Row(
                                              children: [
                                                Icon(Icons.sim_card,
                                                    color: network == 'MTN'
                                                        ? Colors.yellow
                                                        : network == 'Vodafone'
                                                        ? Colors.red
                                                        : Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(network),
                                              ],
                                            ),
                                          )).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => selectedMomoNetwork = value);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _FormLabel('Phone number', required: true),
                                TextFormField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  style:        const TextStyle(color: _C.textPri),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\+?\d*')),
                                  ],
                                  decoration: _fieldDecoration(
                                      'Phone number for ${widget.creditorName}'),
                                  validator: (value) {
                                    final isMomo =
                                    (_paymentMode ?? '').toLowerCase().contains('momo');
                                    if (!isMomo) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Phone number is required for MoMo';
                                    }
                                    if (!RegExp(r'^(?:\+233|0)\d{9}$').hasMatch(value.trim())) {
                                      return 'Enter a valid number (e.g. 0240**** or +23324****)';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Date
                              _FormLabel('Date', required: true),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _dateCtrl,
                                readOnly:   true,
                                onTap:      _pickDate,
                                style:      const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration('dd / mm / yyyy').copyWith(
                                  suffixIcon: const Icon(Icons.calendar_today_outlined,
                                      color: _C.textSub, size: 18),
                                ),
                                validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Date is required' : null,
                              ),

                              const SizedBox(height: 5),

                              //Reference
                              _FormLabel('Reference', required: false),
                              const SizedBox(height: 5),
                              TextFormField(
                                cursorColor: Colors.white,
                                controller: _referenceCtrl,
                                style:      const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration('Transaction reference'),
                              ),

                              /*
                              const SizedBox(height: 5),

                              // Narration
                              _FormLabel('Narrations', required: false),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _narationCtrl,
                                style:      const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration('Payment narration'),
                              ),
                             */
                              const SizedBox(height: 16),

                              //Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    child: _ActionButton(
                                      label:     'Save',
                                      color:     const Color(0xFF2DA58E),
                                      loading:   _saving,
                                      onPressed: _save,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    child: _ActionButton(
                                      label: 'View Records',
                                      color: _C.primary,
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => CreditorPayablelistScreen()),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    child: _ActionButton(
                                      label: 'Reset',
                                      color: const Color(0xFF4B6CB7),
                                      onPressed: () {
                                        _amountCtrl.text = widget.balance;
                                        _dateCtrl.clear();
                                        setState(() {
                                          _paymentMode    = 'Cash Payment';
                                          _paymentAccount = null;

                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String? hint) => InputDecoration(
    hintText:  hint,
    hintStyle: const TextStyle(color: _C.textMuted, fontSize: 13),
    filled:    true,
    fillColor: _C.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.divider)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.negative)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: _C.negative, width: 1.5)),
  );
}

//Shared small widgets
class _FormLabel extends StatelessWidget {
  final String text;
  final bool   required;
  const _FormLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text,
          style: const TextStyle(
              color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w500)),
      if (required)
        const Text(' *', style: TextStyle(color: _C.negative, fontSize: 12)),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final String       label;
  final Color        color;
  final bool         loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.loading  = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: loading
        ? const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

// class _BalanceChip extends StatelessWidget {
//   final num  balance;
//   final bool isOwed;
//   const _BalanceChip(this.balance, this.isOwed);
//
//   @override
//   Widget build(BuildContext context) => Text(
//     ' GHS ${NumberFormat('#,##0.00').format(balance)}',
//     style: TextStyle(
//         color:       _C.textPri,
//         fontWeight: FontWeight.w700,
//         fontSize:   13),
//   );
// }
class _BalanceChip extends StatelessWidget {
  final num  balance;
  final bool isOwed;
  const _BalanceChip(this.balance, this.isOwed);

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerRight,
    child: Text(
      'GHS ${NumberFormat('#,##0.00').format(balance)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          color:       _C.textPri,
          fontWeight: FontWeight.w700,
          fontSize:   13),
    ),
  );
}
class _AmountChip extends StatelessWidget {
  final String text;
  final Color  color;
  const _AmountChip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600));
}
