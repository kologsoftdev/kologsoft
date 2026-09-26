import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/providers/cashier_provider.dart';
import 'package:provider/provider.dart';

import '../models/debtors.dart';
import 'Receivables.dart';

class ViewReceivables extends StatefulWidget {
  const ViewReceivables({super.key});

  @override
  State<ViewReceivables> createState() => _ViewReceivablesState();
}

class _ViewReceivablesState extends State<ViewReceivables> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? selectedDate;
  String searchQuery = '';
  bool _isDateRangeActive=false;
  DateTime? _startDate;
  DateTime? _endDate;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async {
      final provider = Provider.of<CashierProvider>(context, listen: false);
      await provider.DebtorPaymentTransactions();
      await provider.loadDebtors();

    });
  }
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
        });
        final provider = Provider.of<CashierProvider>(context, listen: false);
        await provider.DebtorPaymentTransactions(startDate: _startDate, endDate: _endDate);
      }
    }
  }
  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });

  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  List<Payment>filterdata(List<Payment> payments) {
    if (searchQuery.isEmpty) return payments;

    final query = searchQuery.toLowerCase();
    return payments.where((s) {
      final Name = s.customername.toLowerCase();
      final custumerid = s.customerid.toLowerCase();
      final contact = s.contact.toLowerCase();

      return Name.contains(query) ||custumerid.contains(query)||contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashierProvider>(builder: (BuildContext context, CashierProvider value, Widget? child) {
      final payments  =value.debtpayments;
      final filterpayments = filterdata(payments);

      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text("Debt payments"),
          backgroundColor: const Color(0xFF1B263B),
actions: [
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

],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF415A77),
          child: const Icon(Icons.add),
          onPressed: () {
           Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivablesListPage()),
            );
          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search by name, contact...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF182232),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5,),
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
                  Expanded(
                    child: ListView.builder(
                        itemCount: filterpayments.length,
                        itemBuilder: (context,index){
                          final paymentlists = filterpayments[index];
                          final isDeleting = value.deletingPayments.contains(paymentlists.id);
                          final Debtor? debtor = value.filteredDebtors.where(
                                (d) => d.id == paymentlists.customerid,
                          ).isNotEmpty
                              ? value.filteredDebtors.firstWhere(
                                (d) => d.id == paymentlists.customerid,
                          )
                              : null;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            margin: EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF182232),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.store, color: Colors.blue),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text( paymentlists.customername,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ), ),
                                      const SizedBox(height: 4),
                                      Text( "Amount: GHS ${paymentlists.amount}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      Text(
                                        "Contact: ${paymentlists.contact}",
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                      Text(
                                        "Date: ${paymentlists.createdat}",
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    if(value.canEdit(AppModules.accounts))
                                    InkWell(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => EditPaymentFormDialog(
                                            debtor: debtor!,
                                            payment: paymentlists,
                                            onPaymentSubmitted: (p) {},
                                          ),
                                        );                                      },
                                      child: const Icon(Icons.edit, color: Colors.orange),
                                    ),
                                    SizedBox(width: 8),
                                    if(value.canDelete(AppModules.accounts))
                                      InkWell(
                                    onTap: isDeleting
                          ? null
                              : () async {
                          final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1B263B),
                          title: const Text(
                          "Delete record?",
                          style: TextStyle(color: Colors.white),
                          ),
                          content: Text(
                          "Are you sure you want to delete this transaction?",
                          style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                          TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white70),
                          ),
                          ),
                          TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                          ),
                          ),
                          ],
                          ),
                          );

                          if (confirm == true) {


                            await value.deletePayment(
                              payment: paymentlists,
                              debtorId: paymentlists.customerid,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Transaction deleted successfully")),
                            );

                          }
                          },
                          child: isDeleting
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                          )
                              : const Icon(Icons.delete_forever, color: Colors.red),
                          )

                                  ],
                                )
                              ],
                            ),
                          );

                        }
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
}

class EditPaymentFormDialog extends StatefulWidget {
  final Debtor debtor;
  final Payment payment;
  final Function(Payment) onPaymentSubmitted;

  const EditPaymentFormDialog({
    super.key,
    required this.debtor,
    required this.payment,
    required this.onPaymentSubmitted,
  });

  @override
  State<EditPaymentFormDialog> createState() => _EditPaymentFormDialogState();
}

class _EditPaymentFormDialogState extends State<EditPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  TextEditingController? accountNumberController = TextEditingController();
  TextEditingController? referenceController = TextEditingController();
  String? _selectedAccount;
  List<String> _linkedAccounts = [];
  String method="";
  DateTime _selectedDate = DateTime.now();
  final List<String> momoNetworks = ['MTN', 'Vodafone', 'AirtelTigo', 'Telecel'];
  IconData _getNetworkIcon(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Icons.network_cell;
      case 'vodafone':
        return Icons.signal_cellular_alt;
      case 'airteltigo':
        return Icons.wifi;
      case 'telecel':
        return Icons.phone_android;
      default:
        return Icons.sim_card;
    }
  }

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return const Color(0xFFFFCC00); // MTN Yellow
      case 'vodafone':
        return const Color(0xFFE60000); // Vodafone Red
      case 'airteltigo':
        return const Color(0xFFED1C24); // AirtelTigo Red
      case 'telecel':
        return const Color(0xFF662D91); // Telecel Purple
      default:
        return Colors.grey;
    }
  }


  List<String> _paymentMethods = [];
  String paymentMethod='';
  bool isLoading=false;
  @override
  void initState() {
    super.initState();
    final payment = widget.payment;

    _amountController.text = payment.amount.toString();
    _referenceController.text = payment.reference ?? '';
    _selectedAccount = payment.account;
    paymentMethod = payment.paymentMethod;
    accountNumberController?.text = payment.contact ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_)async {
      final provider=Provider.of<CashierProvider>(context, listen: false);
      await provider.getdata();
      provider.fetchPaymentMethods();
      _paymentMethods=provider.allowedPaymentMethods;

      setState(() {
        _paymentMethods = provider.allowedPaymentMethods;

        if (payment.paymentMethod.isNotEmpty) {
          _linkedAccounts =
              provider.linkedAccounts[payment.paymentMethod] ?? [];
        }

        provider.selectedPaymentMethods[widget.debtor.id] =
            payment.paymentMethod;

        if (payment.paymentMethod.toLowerCase() == 'momo') {
          provider.selectedNetworks[widget.debtor.id] = 'mtn';
        }
      });

    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    double amount = double.parse(_amountController.text);


    try {
      setState(() {
        isLoading=true;
      });
      final provider = Provider.of<CashierProvider>(context, listen: false);
      final paymentId = '${widget.debtor.id}${DateTime.now().millisecondsSinceEpoch}';
      double runningbalance=widget.debtor.balance-amount;

      final payment = Payment(
        id: paymentId,
        amount: amount,
        account: _selectedAccount!,
        reference: _referenceController.text.trim().isEmpty ? 'Payment on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}' : _referenceController.text.trim(),
        paymentMethod: paymentMethod,
        customerid: widget.debtor.id,
        customername: widget.debtor.name,
        createdat: widget.debtor.createdAt!,
        companyid: widget.debtor.companyId,
        companyname: widget.debtor.companyName,
        createdby: widget.debtor.staff,
        contact:widget.debtor.staff,
        runningbalance:runningbalance ,
      );

      Map<String,dynamic> paymentData={
        'contact':widget.debtor.contact,
        'companyid': widget.debtor.companyId,
        'companyname': widget.debtor.companyName,
        'id': widget.payment.id,
        'customerid': payment.customerid,
        'customername': payment.customername,
        'amount': payment.amount,
        'balance': payment.runningbalance,
        'account': payment.account,
        'reference': payment.reference,
        'paymentmethod': payment.paymentMethod,
        'createdat': FieldValue.serverTimestamp(),
        'createdby': widget.debtor.staff,
        'oldamount': widget.payment.amount,
      };
     await provider.debptpayment(paymentData);
      setState(() {
        isLoading=false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful'),
          backgroundColor: Colors.green,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, payment);

    } catch (e) {
      print('Payment error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<CashierProvider>(

        builder: (context, provider, _) {
          String invoiceId=widget.debtor.id;
          String? selectedNetwork = provider.selectedNetworks[invoiceId];
          paymentMethod = provider.selectedPaymentMethods[invoiceId] ?? 'cash';
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFF0A1A2F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                // Balance info
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payment,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Receive Payment',
                                  style: TextStyle(
                                    fontSize: 14,

                                    color: Colors.white,
                                  ),
                                ),

                                Text(
                                  'Customer: ${widget.debtor.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          Flexible(
          child: Center(
          child: ConstrainedBox(constraints:
          const BoxConstraints(maxWidth: 500, ),
          child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              labelStyle: TextStyle(color: Colors.white70),
                                prefixText: 'GHS ',
                                prefixStyle: TextStyle(color: Colors.white),
                                hintText: '0.00',
                                filled: true,
                                fillColor: const Color(0xFF1E3A5F)
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid amount';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Amount must be greater than 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          // Payment Method
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _paymentMethods.contains(paymentMethod) ? paymentMethod : null,
                                dropdownColor: const Color(0xFF1E3A5F),
                                style: const TextStyle(color: Colors.white),
                                isExpanded: true,
                                items: _paymentMethods.map((String method) {
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Row(
                                      children: [
                                        Icon(_getPaymentIcon(method), size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(method),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? value) {
                                  if (value != null && value.isNotEmpty) {
                                    final methodKey = value.toLowerCase();

                                    setState(() {
                                      paymentMethod = methodKey;
                                      _selectedAccount = null;
                                      provider.selectedPaymentMethods[invoiceId] = methodKey;
                                      if (value.toLowerCase() == 'momo') {
                                        provider.selectedNetworks[invoiceId] = 'mtn';
                                      } else {
                                        provider.selectedNetworks[invoiceId] = null;
                                      }
                                      if (methodKey != 'momo') {
                                        provider.selectedNetworks[invoiceId] = null;
                                      }

                                      if (methodKey != 'card') {
                                        provider.selectedCardTypes[invoiceId] = null;
                                      }


                                      if (value != null && value.isNotEmpty) {

                                        _linkedAccounts = provider.linkedAccounts[value]!.toList()?? [];
                                      }
                                    },

                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (paymentMethod.toLowerCase() == 'momo') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedNetwork,
                                dropdownColor: const Color(0xFF1E3A5A),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Select Network',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  prefixIcon: const Icon(Icons.sim_card, color: Colors.white70),
                                  filled: true,
                                  fillColor: const Color(0xFF1E3A5A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: momoNetworks.map((network) {
                                  return DropdownMenuItem(
                                    value: network.toLowerCase(),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getNetworkIcon(network),
                                          color: _getNetworkColor(network),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(network, style: const TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      provider.selectedNetworks[invoiceId] = value;
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (paymentMethod.toLowerCase() == 'momo' && value == null) {
                                    return 'Please select a network';
                                  }
                                  return null;
                                },
                              ),),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:TextFormField(
                                controller: accountNumberController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Mobile Money Number',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  hintText: 'e.g. 055XXXXXXX',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  prefixIcon: const Icon(Icons.phone_android, color: Colors.white70),
                                  filled: true,
                                  fillColor: const Color(0xFF1E3A5A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (paymentMethod.toLowerCase() == 'momo' && (value == null || value.isEmpty)) {
                                    return 'Please enter mobile money number';
                                  }
                                  if (value != null && value.isNotEmpty && !RegExp(r'^0\d{9}$').hasMatch(value)) {
                                    return 'Enter a valid 10-digit number starting with 0';
                                  }
                                  return null;
                                },
                              ),),
                            const SizedBox(height: 12),

                          ],
                          if (paymentMethod.toLowerCase() == 'bank_transfer' || paymentMethod.toLowerCase() == 'cheque') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextFormField(
                                controller: referenceController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: 'Reference Number',
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  hintText: 'Enter Reference Number',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                                  filled: true,
                                  fillColor: const Color(0xFF1E3A5A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (paymentMethod.toLowerCase() == 'cheque' && (value == null || value.isEmpty)) {
                                    return 'Please enter reference number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                          ],
                          _buildLinkedAccountDropdown(),
                          const SizedBox(height: 12),
                          // Date
                          InkWell(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(primary: Colors.blue),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Note/Reference
                          const Text('Narration', style: TextStyle(color: Colors.grey)),
                          TextFormField(
                            controller: _referenceController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Invoice number, description, etc.',
                              hintStyle: TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF1E3A5F),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          Center(
                            child: SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submitPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Text(
                                  'Edit Record',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),],
                      ),
                    ),
                  ),
                ),),
          )],
            ),
          );
        });
  }

  Widget _buildLinkedAccountDropdown() {
    final hasMethod = paymentMethod.isNotEmpty;
    final hasAccounts = _linkedAccounts.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      decoration: InputDecoration(
        labelText: 'Payment Account',
        prefixIcon: const Icon(
          Icons.account_balance_outlined,
          color: Colors.white70,
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: !hasMethod
            ? 'Select payment method first'
            : !hasAccounts
            ? 'No accounts available'
            : null,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E3A5F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
      dropdownColor: const Color(0xFF1E3A5F),
      style: const TextStyle(color: Colors.white),

      onChanged: (!hasMethod || !hasAccounts)
          ? null
          : (value) {
        setState(() {
          _selectedAccount = value!;
        });
      },

      items: _linkedAccounts.map((accountName) {
        return DropdownMenuItem<String>(
          value: accountName,
          child: Text(accountName),
        );
      }).toList(),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a payment account';
        }
        return null;
      },
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Mobile Money':
        return Icons.phone_android;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Cash':
        return Icons.money;
      case 'Cheque':
        return Icons.receipt;
      case 'Credit Card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
}
