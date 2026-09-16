

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'Creditorpayable.dart';


class CreditorPayablelistScreen extends StatefulWidget {
  const CreditorPayablelistScreen({super.key});

  @override
  State<CreditorPayablelistScreen> createState() => _CreditorPayablelistScreenState();
}

class _CreditorPayablelistScreenState extends State<CreditorPayablelistScreen> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  final verticalController = ScrollController();
  final horizontalController = ScrollController();

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

  @override
  void initState() {
    super.initState();
    Future.microtask((){
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchCreditorPaylist(selectedDate, _selectedBranch);
    });

  }

  void _openPaymentDialog(CreditorBalance? creditor) {
    showDialog(
      context: context,
      builder: (_) => _CreditorPaymentDialog(
        creditinfo: creditor,


      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredCreditorpayment = value.filterCreditorPaylist(searchQuery);

        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text('Creditor Payment list View List'),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              ReusableDatePickerWidget(
                child: Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() {
                    selectedDate = selection;

                  });
                  context.read<Datafeed>().fetchCreditorPaylist(selectedDate,_selectedBranch);
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditorPayableScreen()),
              );
            },
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [

                    DropdownButtonFormField<String>(
                      value: _selectedBranch,
                      dropdownColor: const Color(0xFF22304A),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Select Branch',
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        fillColor: const Color(0xFF22304A),
                        filled: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All Branches'),
                        ),
                        ...value.branches.where((branch) => branch.branchtype != 'Warehouse').map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch.id,
                            child: Text(branch.branchname),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedBranch = val ?? '';
                        });
                        value.fetchCreditorPaylist(selectedDate, _selectedBranch);
                      },
                    ),


                    const SizedBox(height: 10),
                    TextFormField(
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search ...',
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon:
                        Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF22304A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),


                    Expanded(
                      child: value.isLoadingcreditpaylist
                          ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                          : value.creditorpayList.isEmpty
                          ? const Center(
                        child: Text(
                          'No Creditor record  found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = screenWidth > 900;


                          if (isDesktop) {
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
                                controller: verticalController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: Scrollbar(
                                  controller: horizontalController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: horizontalController,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 1000, minWidth: 1000),
                                      child: _CreditorListTable(
                                        creditlist: filteredCreditorpayment,
                                        context: context,
                                        sort: _sort,
                                        handleDelete: _handleDelete,
                                        handleEdit: _handleEdit,
                                        sortColumnIndex: _sortColumnIndex,
                                        sortAscending: _sortAscending,
                                        verticalController: verticalController,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          /// MOBILE
                          return ListView.separated(
                            itemCount: filteredCreditorpayment.length,
                            separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final creditorinfo = filteredCreditorpayment[index];

                              final id = creditorinfo.id;
                              final creditorname = creditorinfo.creditorName;
                              final amount = creditorinfo.amount;

                              final paymentMode = creditorinfo.paymentMode;
                              final paymentaccount = creditorinfo.paymentaccount;
                              final transactionRef = creditorinfo.transactionRef;
                              final createdAt = creditorinfo.date;

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
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amberAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Creditor: $creditorname",
                                          softWrap: true,
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [

                                            Text("Amount: GHC $amount",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text("Payment Method: $paymentMode",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text("Payment Account: $paymentaccount",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Transaction Ref: $transactionRef",
                                              maxLines: 2,
                                              softWrap: false,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),

                                            const Divider(color: Colors.white24),

                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFooterLabel(
                                                  Icons.calendar_today_outlined,
                                                  "Date: ${createdAt != null ? DateFormat.yMMMd().format(createdAt) : ''}",
                                                ),
                                              ],
                                            ),

                                            const SizedBox(width: 12),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,

                                              children: [
                                                Expanded(
                                                  child: const Text(
                                                    "TOTAL AMOUNT",
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 5,),
                                                Expanded(
                                                  child: Text(
                                                    "GHC $amount",
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),

                                              ],
                                            ),
                                          ],
                                        ),
                                      ),


                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                              child:  _buildActionButton(
                                                Icons.edit, "Edit",
                                                Colors.blueAccent,
                                                    () {
                                                  _handleEdit( context,
                                                    id,
                                                    creditorinfo,
                                                  );
                                                },
                                              ),
                                          ),
                                          Expanded(
                                              child: _buildActionButton(
                                                Icons.delete_outline, "Delete",
                                                Colors.redAccent, () =>
                                                  _handleDelete(context,creditorinfo, id),
                                              ),
                                          ),

                                        ],
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
  Widget _buildFooterLabel(IconData icon, String label) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white54,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
  Future<void> _handleDelete(BuildContext context, CreditorBalance? creditdata, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
            "Delete close sale by ${creditdata?.creditorName}?",
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
        await context.read<Datafeed>().deleteCreditorpay(creditdata,id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${creditdata?.creditorName}'s Creditor payement deleted successfully"),
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
  Future<void> _handleEdit( BuildContext context, String id, CreditorBalance? creditdata, ) async {
    _openPaymentDialog(creditdata);

  }

}

/// Desktop table rendered with a fixed header row + ListView.builder body,
/// replacing the previous PaginatedDataTable/DataTableSource implementation.
/// Column set, sort mapping and row content are unchanged from the original
/// CreditorDataSource — only the rendering mechanism changed.
class _CreditorListTable extends StatelessWidget {
  final List<CreditorBalance> creditlist;
  final BuildContext context;
  final Function sort;
  final Function handleDelete;
  final Function handleEdit;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ScrollController verticalController;

  const _CreditorListTable({
    required this.creditlist,
    required this.context,
    required this.sort,
    required this.handleDelete,
    required this.handleEdit,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.verticalController,
  });

  static const double _colHash = 40;
  static const double _colCreditor = 150;
  static const double _colAmount = 110;
  static const double _colPaymentMethod = 140;
  static const double _colPaymentAccount = 140;
  static const double _colReference = 120;
  static const double _colDate = 100;
  static const double _colAction = 110;

  Widget _headerCell(String label, double width, {int? columnIndex, Comparable Function(dynamic d)? getField}) {
    final isSorted = columnIndex != null && sortColumnIndex == columnIndex;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: (columnIndex == null || getField == null)
            ? null
            : () {
          final ascending = isSorted ? !sortAscending : true;
          sort(getField, columnIndex, ascending, creditlist);
        },
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted)
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: Colors.white70,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          color: const Color(0xFF1B263B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _headerCell("#", _colHash),
              _headerCell(
                "Creditor",
                _colCreditor,
                columnIndex: 1,
                getField: (d) => d.creditorName ?? '',
              ),
              _headerCell(
                "Amount",
                _colAmount,
                columnIndex: 2,
                getField: (d) => d.amount,
              ),
              _headerCell(
                "Payment Method",
                _colPaymentMethod,
                columnIndex: 3,
                getField: (d) => d.paymentaccount ?? '',
              ),
              _headerCell(
                "Payment Account",
                _colPaymentAccount,
                columnIndex: 4,
                getField: (d) => d.paymentMode ?? '',
              ),
              _headerCell(
                "Reference",
                _colReference,
                columnIndex: 5,
                getField: (d) => d.transactionRef ?? '',
              ),
              _headerCell(
                "Date",
                _colDate,
                columnIndex: 6,
                getField: (d) => d.date ?? '',
              ),
              _headerCell("Action", _colAction),
            ],
          ),
        ),
        Container(height: 0.5, color: Colors.white24),

        // Body
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 700),
          child: ListView.builder(
            controller: verticalController,
            shrinkWrap: true,
            itemCount: creditlist.length,
            itemBuilder: (context, index) {
              final creditview = creditlist[index];

              final id = creditview.id;
              final creditor = creditview.creditorName;
              final amount = creditview.amount;
              final paymentMode = creditview.paymentMode;
              final transactionRef = creditview.transactionRef;
              final paymentAccount = creditview.paymentaccount;
              final createdAt = creditview.date;

              return Container(
                color: index.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF0F2033),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _dataCell("${index + 1}", _colHash),
                    _dataCell(creditor, _colCreditor),
                    _dataCell("GHC $amount", _colAmount),
                    _dataCell(paymentMode, _colPaymentMethod),
                    _dataCell(paymentAccount ?? '', _colPaymentAccount),
                    _dataCell(transactionRef, _colReference),
                    _dataCell(
                      createdAt != null ? DateFormat.yMMMd().format(createdAt) : '',
                      _colDate,
                    ),
                    SizedBox(
                      width: _colAction,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () {
                              handleEdit(
                                context,
                                id,
                                creditview,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => handleDelete(context, creditview, id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreditorPaymentDialog extends StatefulWidget {
  //final String selectedBranch;
  final CreditorBalance? creditinfo;
  const _CreditorPaymentDialog({
    //required this.selectedBranch,
    this.creditinfo,
  });

  @override
  State<_CreditorPaymentDialog> createState() => _CreditorPaymentDialogState();
}

class _CreditorPaymentDialogState extends State<_CreditorPaymentDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _narationCtrl = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateCtrl   = TextEditingController();
  DateTime? _selectedDate;
  String? _paymentMode;
  String? _paymentAccount;
  bool   _saving = false;
  String? selectedMomoNetwork = 'MTN';
  final db =FirebaseFirestore.instance;

  void showMessage(BuildContext context, Color color, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      await datafeed.getdata();
      context.read<Datafeed>().fetchPaymentMethods();
      final data = widget.creditinfo;

      if (data != null) {
        _amountCtrl.text = data.amount?.toString() ?? '';

        _referenceCtrl.text = data.transactionRef;

        _narationCtrl.text = data.naration ?? '';

        _paymentMode = data.paymentMode.trim();

        _paymentAccount =  data.paymentaccount;
        _phoneController.text =data.phone!;
        selectedMomoNetwork = data.networktype;

        if (data.date != null) {
          _selectedDate = data.date;
          _dateCtrl.text =
              DateFormat('dd/MM/yyyy')
                  .format(data.date!);
        }

        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final datafeed = Provider.of<Datafeed>(context);

    if (!datafeed.isLoadingPaymentMethods &&
        datafeed.allowedPaymentMethods.isNotEmpty &&
        _paymentMode != null) {
      setState(() {});
    }
  }
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _C.primary, surface: _C.card),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dateCtrl.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }



  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    print(_paymentMode);
    if ((_paymentMode ?? '').toLowerCase().contains('MOMO') &&
        (selectedMomoNetwork == null || selectedMomoNetwork!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select MoMo network')),
      );
      return;
    }

    // Guard: prevent concurrent
    if (_saving) return;
    setState(() => _saving = true);


    final datafeed    = Provider.of<Datafeed>(context, listen: false);
    final docId       = widget.creditinfo?.id;
    final supplierid  = widget.creditinfo?.creditorId;
    final oldAmount   = widget.creditinfo?.amount;        // snapshot now
    final amountText  = _amountCtrl.text.trim();          // snapshot now
    final transRef    = _referenceCtrl.text.trim();
    final naration    = _narationCtrl.text.trim();
    final phone       = _phoneController.text.trim();
    final paymentMode = _paymentMode ?? '';
    final payAccount  = _paymentAccount ?? '';
    final selectedDate = _selectedDate;

    // ── Validate critical
    if (docId == null || docId.isEmpty || supplierid == null || supplierid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid record: missing ID')),
      );
      setState(() => _saving = false);
      return;
    }

    final double newAmount;
    try {
      newAmount = double.parse(amountText);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount entered')),
      );
      setState(() => _saving = false);
      return;
    }

    // Delta: edit → difference; new record → full amount
    final double debitIncrement = (oldAmount != null)
        ? newAmount - oldAmount
        : newAmount;

    final now = DateTime.now();

    final day = DateFormat('EEEE').format(now);

    final year = now.year.toString();

    final month = '${now.year}.${now.month}';

    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

    final week = '${now.year}.$weekNumber';
    final creditpay = CreditorBalance(
      id:             docId,
      creditorId:     widget.creditinfo!.creditorId,
      creditorName:   widget.creditinfo!.creditorName,
      amount:         newAmount,
      type:           'credit payment',
      paymentMode:    paymentMode,
      transactionRef: transRef,
      naration:       naration,
      phone:          phone,
      date:           selectedDate,
      branchid:       datafeed.branchid,
      companyid:      datafeed.companyid,
      companyemail:   datafeed.companyemail,
      paymentaccount: payAccount,
      staff:          datafeed.staff,
      updatedby:      datafeed.staff,
      updatedat:      DateTime.now(),
      day: day,
      week: week,
      month: month,
      yearr: year,
    );

    try {
      final batch = datafeed.db.batch();

      // 1. Upsert the payment document
      batch.set(
        datafeed.db.collection('creditor_payments').doc(docId),
        creditpay.toMap(),
      );

      // 2. Apply delta only
      if (debitIncrement != 0) {
        batch.update(
          FirebaseFirestore.instance.collection('suppliers').doc(supplierid),
          {'debitaccount': FieldValue.increment(debitIncrement)},
        );
      }

      await batch.commit(); // single atomic
      final indexed = datafeed.creditorpayList.indexWhere((t)=>t.id==docId);
      if(indexed == -1){
        datafeed.creditorpayList.add(creditpay);
      }
      else{
        datafeed.creditorpayList[indexed]=creditpay;
      }
      datafeed.notifyListeners();
      if (!mounted) return;

      // Clear form only after
      _amountCtrl.clear();
      _dateCtrl.clear();
      _referenceCtrl.clear();
      _narationCtrl.clear();
      setState(() {
        _paymentMode    = null;
        _paymentAccount = null;
      });

      // Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment updated successfully'),
          backgroundColor: _C.positive,
        ),
      );

      Navigator.pop(context); // pop AFTER

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _C.negative),
      );
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
                  scrollDirection: Axis.vertical,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header
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
                                      'PAYABLES — ${widget.creditinfo!.creditorName.toUpperCase()}',
                                      style: const TextStyle(
                                          color: _C.primary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Amount: ${widget.creditinfo!.amount} GHC',
                                      style: const TextStyle(
                                          color: _C.textSub, fontSize: 12),
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

                        // ── Form body
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [

                              // Amount
                              _FormLabel('Amount', required: true),
                              const SizedBox(height: 5),
                              TextFormField(
                                cursorColor: Colors.white,
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                style: const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration(
                                    'Input the amount you are paying to ${widget.creditinfo!.creditorName}'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                                  if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                                  if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 5),
                              // Payment Mode
                              _FormLabel('Payment Mode', required: true),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                value: datafeed.allowedPaymentMethods.any(
                                      (m) => m.trim() == _paymentMode?.trim(), )
                                    ? datafeed.allowedPaymentMethods.firstWhere(
                                      (m) => m.trim() == _paymentMode?.trim(), )
                                    : null,
                                isExpanded: true,
                                dropdownColor: _C.card,
                                style: const TextStyle(color: _C.textPri),

                                hint: const Text(
                                  'Select Payment Mode',
                                  style: TextStyle(color: _C.textMuted),
                                ),

                                decoration: _fieldDecoration(null),

                                //  CORRECT SOURCE
                                items: datafeed.allowedPaymentMethods
                                    .map((m) => DropdownMenuItem<String>(
                                  value: m,
                                  child: Text(m),
                                ))
                                    .toList(),

                                onChanged: (v) {
                                  setState(() {
                                    // _paymentMode = v;
                                    // _paymentAccount = null; // reset account
                                    _paymentMode    = v;
                                    // _paymentAccount = null;
                                    final accounts = (v == null || v.isEmpty)  ? <String>[] : datafeed.getAccounts(v);
                                    if (accounts.length == 1) {
                                      _paymentAccount = accounts.first;
                                    } else {
                                      _paymentAccount = null;
                                    }
                                  });
                                },

                                validator: (v) =>
                                (v == null || v.isEmpty) ? 'Select payment mode' : null,
                              ),

                              const SizedBox(height: 5),
                              // Payment Account
                              _FormLabel('Payment Account', required: true),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                value: (_paymentAccount != null && _paymentAccount!.isNotEmpty)
                                    ? _paymentAccount
                                    : null,

                                dropdownColor: _C.card,
                                style: const TextStyle(color: _C.textPri),

                                hint: const Text(
                                  'Select account',
                                  style: TextStyle(color: _C.textMuted),
                                ),

                                decoration: _fieldDecoration(null),

                                //SAFE ITEMS
                                items: (_paymentMode == null || _paymentMode!.isEmpty)
                                    ? []
                                    : datafeed.getAccounts(_paymentMode!)
                                    .map((a) => DropdownMenuItem<String>(value: a,child: Text(a),)).toList(),

                                onChanged: (_paymentMode == null || _paymentMode!.isEmpty)
                                    ? null
                                    : (v) => setState(() => _paymentAccount = v),

                                validator: (v) {
                                  if (_paymentMode == null || _paymentMode!.isEmpty) {
                                    return 'Select payment mode first';
                                  }
                                  if (v == null || v.isEmpty) {
                                    return 'Select a payment account';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 5),
                              if ((_paymentMode ?? '').toLowerCase().contains('momo'))...[
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
                                      // ← guard: only use value if it exists in the list, else null
                                      value: ['MTN', 'Vodafone', 'AirtelTigo'].contains(selectedMomoNetwork)
                                          ? selectedMomoNetwork
                                          : 'MTN',
                                      isExpanded: true,
                                      hint: const Text(
                                        'Select MOMO Network',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      dropdownColor: _C.card,
                                      style: const TextStyle(color: Colors.white),
                                      items: ['MTN', 'Vodafone', 'AirtelTigo'].map(
                                            (network) => DropdownMenuItem<String>(
                                          value: network,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.sim_card,
                                                color: network == 'MTN'
                                                    ? Colors.yellow
                                                    : network == 'Vodafone'
                                                    ? Colors.red
                                                    : Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(network),
                                            ],
                                          ),
                                        ),
                                      ).toList(),
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
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: _C.textPri),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\+?\d*')),
                                  ],
                                  decoration: _fieldDecoration(
                                      'Input the Phone number you are paying to ${widget.creditinfo?.creditorName}'),
                                  validator: (value) {
                                    final isMomo = (_paymentMode ?? '').toLowerCase().contains('momo');
                                    if (!isMomo) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Phone number is required for MoMo payment';
                                    }
                                    if (!RegExp(r'^(?:\+233|0)\d{9}$').hasMatch(value.trim())) {
                                      return 'Enter a valid number (e.g. 0240**** or +23324****)';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 5),

                              // Date
                              _FormLabel('Date', required: true),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _dateCtrl,
                                readOnly: true,
                                onTap: _pickDate,
                                style: const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration('dd / mm / yyyy').copyWith(
                                  suffixIcon: const Icon(Icons.calendar_today_outlined,
                                      color: _C.textSub, size: 18),
                                ),
                                validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Date is required' : null,
                              ),

                              const SizedBox(height: 5),
                              _FormLabel('Reference', required: false),
                              const SizedBox(height: 5),
                              TextFormField(
                                cursorColor: Colors.white,
                                controller: _referenceCtrl,
                                keyboardType: TextInputType.text,

                                style: const TextStyle(color: _C.textPri),
                                decoration: _fieldDecoration(
                                    'Input the Reference you are paying to ${widget.creditinfo!.creditorName}'),

                              ),
                              const SizedBox(height: 5),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ActionButton(
                                    label: 'Save',
                                    color: const Color(0xFF2DA58E),
                                    loading: _saving,
                                    onPressed: _save,
                                  ),
                                  const SizedBox(width: 12),
                                  _ActionButton(
                                    label: 'View Records',
                                    color: _C.primary,
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context)=> CreditorPayablelistScreen(),
                                      )
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _ActionButton(
                                    label: 'Reset',
                                    color: const Color(0xFF4B6CB7),
                                    onPressed: () {
                                      _amountCtrl.text = widget.creditinfo!.amount.toString();
                                      _referenceCtrl.text = widget.creditinfo!.transactionRef ?? '';
                                      _narationCtrl.text = widget.creditinfo!.naration ?? '';
                                      _dateCtrl.clear();
                                      setState(() {
                                        _paymentMode    = 'Cash Payment';
                                        _paymentAccount = null;
                                      });
                                    },
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
    hintText: hint,
    hintStyle: const TextStyle(color: _C.textMuted, fontSize: 13),
    filled: true,
    fillColor: _C.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _C.divider)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _C.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _C.negative)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _C.negative, width: 1.5)),
  );
}
class _C {
  static const bg       = Color(0xFF0F1117);
  static const surface  = Color(0xFF1A1D27);
  static const card     = Color(0xFF1F2333);
  static const header   = Color(0xFF0D1A26);
  static const divider  = Color(0xFF2C2F3E);
  static const primary  = Color(0xFF3B82F6);
  static const positive = Color(0xFF22C55E);
  static const negative = Color(0xFFEF4444);
  static const warning  = Color(0xFFF59E0B);
  static const textPri  = Color(0xFFE2E8F0);
  static const textSub  = Color(0xFF94A3B8);
  static const textMuted= Color(0xFF4B5563);
}
class _FormLabel extends StatelessWidget {
  final String text;
  final bool   required;
  const _FormLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w500)),
        if (required)
          const Text(' *', style: TextStyle(color: _C.negative, fontSize: 12)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String  label;
  final Color   color;
  final bool    loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: loading
          ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}