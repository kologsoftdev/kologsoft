import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../models/debtors.dart';
import '../providers/cashier_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceivablesListPage extends StatefulWidget {
  const ReceivablesListPage({super.key});

  @override
  State<ReceivablesListPage> createState() => _ReceivablesListPageState();
}

class _ReceivablesListPageState extends State<ReceivablesListPage> {


  @override

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async {
      final provider = Provider.of<CashierProvider>(context, listen: false);
     await provider.loadDebtors();
    });
  }



  @override
  Widget build(BuildContext context) {
    return Consumer<CashierProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A1A2F),
            appBar: AppBar(
              title: const Text(
                'Receivables',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0D2A4A),
              foregroundColor: Colors.white,
            ),
            body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Outstanding',
                                'GHS ${NumberFormat('#,##0.00').format(provider.totalOutstandingBalance)}',
                                Icons.account_balance_wallet,
                                Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Collected',
                                'GHS ${NumberFormat('#,##0.00').format(provider.totalCollected)}',
                                Icons.payments,
                                Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search by name, phone, or ID...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(
                                  Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              filled: true,
                              fillColor: const Color(0xFF22304A)
                            ),
                            onChanged: (value) {
                              provider.setSearchQuery(value);
                            },                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Unpaid', 'Unpaid'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Partial', 'Partial'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Paid', 'Paid'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      provider.filteredDebtors.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors
                                .grey.shade600),
                            const SizedBox(height: 16),
                            Text(
                              'No debtors found',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                          : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: provider.filteredDebtors.length,
                          itemBuilder: (context, index) {
                            final debtor = provider.filteredDebtors[index];
                            return DebtorCard(
                              debtor: debtor,
                              onReceivePayment: () {
                                _showPaymentDialog(context, debtor,provider);
                              },
                              onViewDetails: () {
                                _showDebtorDetails(context, debtor);
                              },
                            );
                          },
                        ),
                      ),


                    ],
                  ),)
            ),);
        });

  }

  Widget _buildSummaryCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF0D2A4A),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final provider = Provider.of<CashierProvider>(context);
    return FilterChip(
      label: Text(label),
      selected: provider.statusFilter == value,
      onSelected: (selected) {
        provider.setStatusFilter(value);
      },
      backgroundColor: const Color(0xFF1E3A5F),
      selectedColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: provider.statusFilter == value ? Colors.white : Colors.grey.shade300,
      ),
      checkmarkColor: Colors.white,
    );
  }

  void _showPaymentDialog(BuildContext context, Debtor debtor,CashierProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentFormDialog(
        debtor: debtor,
        onPaymentSubmitted: (payment) {
          provider.addPaymentToDebtor(debtor.id, payment);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment of GHS ${payment.amount} recorded for ${debtor.name}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showDebtorDetails(BuildContext context, Debtor debtor) async{
    final provider = Provider.of<CashierProvider>(context, listen: false);
     provider.loadDebtorDetails(customerid: debtor.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebtorDetailsDialog(
        debtor: debtor,
        onPaymentAdded: (payment) {
          provider.addPaymentToDebtor(debtor.id, payment);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddDebtorDialog(BuildContext context) {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AddDebtorDialog(
        onDebtorAdded: (newDebtor) {
            provider.filteredDebtors.add(newDebtor);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newDebtor.name} added as debtor'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

}

class DebtorCard extends StatelessWidget {
  final Debtor debtor;
  final VoidCallback onReceivePayment;
  final VoidCallback onViewDetails;

  const DebtorCard({
    super.key,
    required this.debtor,
    required this.onReceivePayment,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E3A5F),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              debtor.contact,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: debtor.statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: debtor.statusColor),
                    ),
                    child: Text(
                      debtor.status,
                      style: TextStyle(color: debtor.statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Progress',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      Text(
                        '${(debtor.paymentProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: debtor.paymentProgress,
                      backgroundColor: Colors.grey.shade800,
                      color: debtor.statusColor,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAmountColumn('Total Debt', 'GHS ${NumberFormat('#,##0.00').format(debtor.creditBalance)}', Colors.white),
                  _buildAmountColumn('Amount Paid', 'GHS ${NumberFormat('#,##0.00').format(debtor.amountpaid)}', Colors.white),
                  _buildAmountColumn('Balance', debtor.balance < 0 ? '(GHS ${NumberFormat('#,##0.00').format(debtor.balance.abs())})'
                        : 'GHS ${NumberFormat('#,##0.00').format(debtor.balance)}',
                    Colors.orange.shade400,
                  ),                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReceivePayment,
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Receive Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.grey.shade400,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2A4A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountColumn(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


class PaymentFormDialog extends StatefulWidget {
  final Debtor debtor;
  final Function(Payment) onPaymentSubmitted;

  const PaymentFormDialog({
    super.key,
    required this.debtor,
    required this.onPaymentSubmitted,
  });

  @override
  State<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
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

  TextEditingController? accountNumberController = TextEditingController();
  TextEditingController? _contactController = TextEditingController();
  TextEditingController? referenceController = TextEditingController();
   List<String> _paymentMethods = [];
  String paymentMethod='';
  bool isLoading=false;
  
  // MOMO Transaction Variables
  List<TextEditingController> momoTransactionControllers = [TextEditingController()];
  List<TextEditingController> momoTransactionAmountControllers = [TextEditingController()];
  List<bool> momoTransactionAmountLoaded = [false];
  List<Timer?> momoTransactionTimers = [null];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)async {
      final provider=Provider.of<CashierProvider>(context, listen: false);
      await provider.getdata();
      provider.fetchPaymentMethods();
    _paymentMethods=provider.allowedPaymentMethods;

    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    
    // Dispose MOMO transaction controllers
    for (var controller in momoTransactionControllers) {
      controller.dispose();
    }
    for (var controller in momoTransactionAmountControllers) {
      controller.dispose();
    }
    for (var timer in momoTransactionTimers) {
      timer?.cancel();
    }
    
    super.dispose();
  }
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final now = DateTime.now();
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }

  void updateMomoPaidTotal() {
    final total = momoTransactionAmountControllers
        .map((controller) => double.tryParse(controller.text.trim()) ?? 0)
        .fold(0.0, (sum, value) => sum + value);
    setState(() {
      _amountController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> fetchMomoAmountForTransaction(int index) async {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final transactionId = momoTransactionControllers[index].text.trim();
    
    if (transactionId.isEmpty) {
      return;
    }
    
    try {
      final query = await FirebaseFirestore.instance
          .collection('momo')
          .where('transactionId', isEqualTo: transactionId)
          .where('companyid', isEqualTo: provider.companyid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MOMO transaction $transactionId not found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      final doc = query.docs.first;
      final momoData = doc.data();
      final statusValue = momoData['status']?.toString().toLowerCase() ?? '';
      
      if (statusValue == 'saved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction ID $transactionId has already been used'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      final amountText = momoData['amount']?.toString() ?? '';
      final amount = double.tryParse(amountText);
      
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to parse amount for transaction $transactionId'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      setState(() {
        momoTransactionAmountControllers[index].text = amount.toStringAsFixed(2);
        momoTransactionAmountLoaded[index] = true;
        updateMomoPaidTotal();
      });
    } catch (e) {
      print('Error fetching MOMO transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  String? momoType;
  bool validateMomoTransactions() {
    final transactionEntries = <Map<String, dynamic>>[];
    for (int i = 0; i < momoTransactionControllers.length; i++) {
      final transactionId = momoTransactionControllers[i].text.trim();
      final amountText = momoTransactionAmountControllers[i].text.trim();
      final transactionAmount = double.tryParse(amountText);

      if (transactionId.isEmpty && amountText.isEmpty) continue;
      
      if (transactionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter transaction ID ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter amount for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      if (!momoTransactionAmountLoaded[i]) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submit transaction ID ${i + 1} to load amount'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      if (transactionAmount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid amount for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      if (transactionAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Amount must be greater than 0 for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      
      transactionEntries.add({
        'transactionId': transactionId,
        'amount': transactionAmount,
      });
    }

    if (transactionEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one MOMO transaction ID and amount'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    
    return true;
  }

  Map<String, dynamic> getMomoTransactionMap() {
    final transactionMap = <String, dynamic>{};
    for (int i = 0; i < momoTransactionControllers.length; i++) {
      final transactionId = momoTransactionControllers[i].text.trim();
      final amount = double.tryParse(momoTransactionAmountControllers[i].text.trim());
      if (transactionId.isEmpty || amount == null) continue;
      transactionMap[transactionId] = {
        'id': transactionId,
        'amount': amount,
      };
    }
    return transactionMap;
  }
  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white),
      prefixIcon: prefix != null ? Icon(prefix, color: Colors.white70) : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate MOMO transactions if payment method is MOMO
    if (paymentMethod.toLowerCase() == 'momo' && momoType=='merchant') {
      if (!validateMomoTransactions()) {
        return;
      }
    }

    double amount = double.parse(_amountController.text);

    try {
      setState(() {
        isLoading=true;
      });
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final paymentId = '${widget.debtor.id}${DateTime.now().millisecondsSinceEpoch}${provider.staffPosition}';
       double runningbalance=widget.debtor.balance-amount;

    final paymentMethodKey = paymentMethod.toLowerCase();
    final paymentMethodStore = paymentMethodKey == 'mobile money' ? 'momo' : paymentMethodKey;
    final selectedNetwork = provider.selectedNetworks[widget.debtor.id] ?? 'mtn';
    final momoTransactionIds = paymentMethodStore == 'momo' ? getMomoTransactionMap() : null;
    final paymentAccountName = paymentMethodStore == 'momo'
        ? selectedNetwork.toUpperCase()
        : (_selectedAccount ?? '');
    final paymentAccountNumber = paymentMethodStore == 'momo'
        ? accountNumberController?.text.trim() ?? ''
        : (_selectedAccount ?? '');
    final paymentReference = _referenceController.text.trim().isEmpty
        ? (paymentMethodStore == 'momo'
            ? paymentAccountNumber
            : 'Payment on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}')
        : _referenceController.text.trim();

    final payment = Payment(
      id: paymentId,
      amount: amount,
      account: _selectedAccount!,
      reference: paymentReference,
      paymentMethod: paymentMethodStore,
      customerid: widget.debtor.id,
      customername: widget.debtor.name,
      createdat: widget.debtor.createdAt!,
     companyid: widget.debtor.companyId,
     companyname: widget.debtor.companyName,
      createdby: widget.debtor.staff,
      contact:widget.debtor.staff,
      runningbalance:runningbalance ,
    );

      final paymentEntry = {
        'accountName': paymentAccountName,
        'accountNumber': paymentAccountNumber,
        'amount': payment.amount,
        'method': paymentMethodStore,
        'reference': paymentReference,
        'status': paymentMethodStore == 'momo' ? false : true,
        if (momoTransactionIds != null && momoTransactionIds.isNotEmpty) 'transactionIds': momoTransactionIds,
      };

      Map<String,dynamic> paymentData={
        'contact':widget.debtor.contact,
    'companyid': widget.debtor.companyId,
    'companyname': widget.debtor.companyName,
    'id': payment.id,
    'customerid': payment.customerid,
    'customername': payment.customername,
    'amount': payment.amount,
    'balance': payment.runningbalance,
    'account': payment.account,
    'reference': payment.reference,
    'paymentmethod': payment.paymentMethod,
    'payments': [paymentEntry],
    'createdat': FieldValue.serverTimestamp(),
    'createdby': widget.debtor.staff,
    'oldamount': 0,
    'transType': "debt payment",
    'branchName': widget.debtor.branchName,
    'branchId': widget.debtor.branchId,
    'staffemail':provider.staffemail,
    'date': today,
    'year': now.year.toString(), // 2026
    'month': '${now.year}.${now.month}', // 2026.5
    'week': '${now.year}.${weekNumber(now)}', // 2026.32
    'day': DateFormat('EEEE').format(now),

};
      final formatter = NumberFormat.currency(
        locale: 'en_GH',
        symbol: 'GHS',
        decimalDigits: 2,
      );

      String smsamount = formatter.format(payment.amount);
      String smsbalance = formatter.format(runningbalance);

        await provider.debptpayment(paymentData);
      final smsRecord = {
        'companyid': provider.companyid,
        'branchid': provider.branchid,
        'staff': provider.staff,
        'message': "Dear ${payment.customername},We acknowledge receipt of your payment of ${smsamount}.Your remaining balance is ${smsbalance}. Thank you.",
        'senderid': "",
        'recipient': widget.debtor.contact,
        'type': 'single',
        'bulkFilterType': null,
        'status': 'pending',
        'successMessage': '',
        'failureReason': '',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await provider.db.collection('sms_logs').add(smsRecord);

        if (paymentMethodStore == 'momo' && momoTransactionIds != null) {
          for (final transactionId in momoTransactionIds.keys) {
            final query = await provider.db.collection('momo')
                .where('transactionId', isEqualTo: transactionId)
                .where('companyid', isEqualTo: provider.companyid)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              await query.docs.first.reference.update({
                'status': 'saved',
                'paymentids': FieldValue.arrayUnion([paymentId]),
              });
            }
          }
        }

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
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payment, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receive Payment',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Debtor: ${widget.debtor.name}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Balance info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade700),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Balance:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  'GHS ${NumberFormat('#,##0.00').format(widget.debtor.balance)}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount
                    const Text('Amount to Pay *', style: TextStyle(color: Colors.grey,fontSize: 12)),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        prefixText: 'GHS ',
                        prefixStyle: TextStyle(color: Colors.white),
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.white),
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
                    const SizedBox(height: 4),
                    // Payment Method
                    const Text('Payment Method *', style: TextStyle(color: Colors.grey,fontSize: 12)),
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
                              final methodKey = value.toLowerCase() .replaceAll('_', ' ')
                                  .trim();

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
                                    print('Selected payment method: $methodKey');
                                    _linkedAccounts = provider.linkedAccounts[methodKey]?.toList() ?? [];
                                    // _linkedAccounts = provider.linkedAccounts[value]!.toList()?? [];
                                  }
                                },

                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
       // "hubtel" or "merchant"

        if (paymentMethod.toLowerCase() == 'momo') ...[
          const SizedBox(height: 5),
        // Select Network
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
        Icon(_getNetworkIcon(network),
        color: _getNetworkColor(network), size: 20),
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
        ),
        ),

        const SizedBox(height: 10),

        // New dropdown for Hubtel vs Merchant
        Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonFormField<String>(
        value: momoType,
        dropdownColor: const Color(0xFF1E3A5A),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
        labelText: 'Payment Type',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1E3A5A),
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
        ),
        ),
        items: const [
        DropdownMenuItem(value: 'hubtel', child: Text('Hubtel')),
        DropdownMenuItem(value: 'merchant', child: Text('Merchant')),
        ],
        onChanged: (value) {
        setState(() {
        momoType = value;
        });
        },
        validator: (value) {
        if (paymentMethod.toLowerCase() == 'momo' && value == null) {
        return 'Please select payment type';
        }
        return null;
        },
        ),
        ),
          const SizedBox(height: 5),
        ],

//  Conditionally show transaction fields only if Merchant is selected
        if (paymentMethod.toLowerCase() == 'momo' && momoType == 'merchant') ...[
          const SizedBox(height: 5),
        _buildMomoTransactionFields(),
        ],
                    if (paymentMethod.toLowerCase() == 'momo' && momoType == 'hubtel') ...[
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _contactController,
                        style: TextStyle(color: Colors.white70),
                        decoration:_inputDecoration(label: "Phone Number",
                          prefix: Icons.phone,
                          hint: 'Enter contact number',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+]'),
                          ),
                          LengthLimitingTextInputFormatter(13),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          // Remove spaces and check format
                          String cleaned = v.replaceAll(' ', '');
                          // Ghana phone: 0XXXXXXXXX (10 digits) or +233XXXXXXXXX (13 chars)
                          if (cleaned.startsWith('+233')) {
                            if (cleaned.length != 13 ||
                                !RegExp(r'^\+233\d{9}$').hasMatch(cleaned)) {
                              return 'Invalid format. Use +233XXXXXXXXX';
                            }
                          } else if (cleaned.startsWith('0')) {
                            if (cleaned.length != 10 ||
                                !RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
                              return 'Invalid format. Use 0XXXXXXXXX';
                            }
                          } else {
                            return 'Phone must start with 0 or +233';
                          }
                          return null;
                        },
                      ),

                    ],

                    if (paymentMethod.toLowerCase() == 'bank_transfer'|| paymentMethod.toLowerCase() == 'cheque') ...[
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

                    ],
                    const SizedBox(height: 5),
                    _buildLinkedAccountDropdown(),
                    const SizedBox(height: 5),
                    // Date
                    const Text('Payment Date *', style: TextStyle(color: Colors.grey,fontSize: 12)),
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
                    const SizedBox(height: 5),

                    // Note/Reference
                    const Text('Narration', style: TextStyle(color: Colors.grey,fontSize: 12)),

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
                    const SizedBox(height: 15),

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
                            'Record Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),                  ],
                ),
              ),
            ),
          ),
        ],
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
        hintStyle: const TextStyle(color: Colors.white),
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

  Widget _buildMomoTransactionFields() {
    if (paymentMethod.toLowerCase() != 'momo') {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('MOMO Transactions', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Column(
          children: [
            for (int index = 0; index < momoTransactionControllers.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: momoTransactionAmountLoaded[index]
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: momoTransactionControllers[index],
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: 'Transaction ID',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                hintText: 'e.g., MTN12345678',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                prefixIcon: const Icon(Icons.receipt_long, color: Colors.white70),
                                filled: true,
                                fillColor: const Color(0xFF0D1B2A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: momoTransactionControllers[index].text.isEmpty
                                ? null
                                : () => fetchMomoAmountForTransaction(index),
                            child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: momoTransactionAmountControllers[index],
                        readOnly: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixText: 'GHS ',
                          prefixStyle: const TextStyle(color: Colors.green),
                          filled: true,
                          fillColor: const Color(0xFF0D1B2A),
                          suffixIcon: momoTransactionAmountLoaded[index]
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    momoTransactionControllers.add(TextEditingController());
                    momoTransactionAmountControllers.add(TextEditingController());
                    momoTransactionAmountLoaded.add(false);
                    momoTransactionTimers.add(null);
                  });
                },
                icon: const Icon(Icons.add, color: Colors.blue),
                label: const Text(
                  'Add Transaction',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DebtorDetailsDialog extends StatelessWidget {
  final Debtor debtor;
  final Function(Payment) onPaymentAdded;

  const DebtorDetailsDialog({
    super.key,
    required this.debtor,
    required this.onPaymentAdded,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CashierProvider>(context);
    final payments = provider.debtordetails;
    double runningTotal = 0;
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.createdat.compareTo(b.createdat));
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1A2F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debtor.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          // Text(
                          //   'ID: ${debtor.id}',
                          //   style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          // ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  _infoTile(Icons.phone, 'Phone', debtor.contact),
                  _infoTile(Icons.email, 'Email', "debtor's email"),
                  _infoTile(Icons.calendar_today, 'Customer Since', DateFormat('MMM dd, yyyy').format(debtor.createdAt!)),

                  const SizedBox(height: 24),
                  const Text(
                    'Financial Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _financialRow('Total Debt', 'GHS ${NumberFormat('#,##0.00').format(debtor.creditBalance)}', Colors.white),
                        const Divider(color: Colors.grey),
                        _financialRow('Amount Paid', 'GHS ${NumberFormat('#,##0.00').format(debtor.amountpaid)}', Colors.white),
                        const Divider(color: Colors.grey),
                        _financialRow(
                          'Balance',
                          debtor.balance < 0
                              ? '(GHS ${NumberFormat('#,##0.00').format(debtor.balance.abs())})'
                              : 'GHS ${NumberFormat('#,##0.00').format(debtor.balance)}',
                          Colors.orange,bold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment History',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        color: Colors.green,
                        onPressed: () => _downloadPdf(context, payments),
                        icon: const Icon(Icons.print),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (provider.isLoadingDetails)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (payments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No payments recorded yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedPayments.length,
                      itemBuilder: (context, index) {
                        final payment = sortedPayments[index];
                        runningTotal += payment.amount;
                       double runningbalance = debtor.creditBalance - runningTotal;
                        return _paymentHistoryTile(payment,debtor.creditBalance,runningbalance);
                      },
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => PaymentFormDialog(
                                debtor: debtor,
                                onPaymentSubmitted: (payment) {
                                  onPaymentAdded(payment);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Payment of GHS ${payment.amount} recorded'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text('Record Payment',style: TextStyle(color: Colors.white),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: bold ? 18 : 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentHistoryTile(Payment payment,double creditbalance,double runningbalance) {

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A4A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getPaymentIcon(payment.paymentMethod), size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'GHS ${NumberFormat('#,##0.00').format(payment.amount)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  payment.paymentMethod,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Balance: GHS ${NumberFormat('#,##0.00').format(runningbalance)}",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          Text(
            DateFormat('MMM dd, yyyy').format(payment.createdat),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          if (payment.reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ref: ${payment.reference}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
          Text(
            'Account: ${payment.account}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
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
      default:
        return Icons.payment;
    }
  }

  Future<void> _downloadPdf(BuildContext context, List<Payment> payments) async {
    final pdf = pw.Document();

    // Calculate summary statistics
    final totalPaid = payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    final currentBalance = debtor.creditBalance - totalPaid;
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.createdat.compareTo(b.createdat));

    pdf.addPage(
      pw.MultiPage(
        //pageFormat:pw.PageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header Section
            _buildHeaderSection(),

            pw.SizedBox(height: 30),

            // Summary Cards Section
            _buildSummarySection(totalPaid, currentBalance),

            pw.SizedBox(height: 30),

            // Payment History Section
            _buildPaymentHistorySection(sortedPayments, debtor.creditBalance),

            pw.SizedBox(height: 20),

            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Debtor_Statement_${debtor.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

// Helper method for header section
  pw.Widget _buildHeaderSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "${debtor.companyName.toUpperCase()}",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "Debtor Statement of Account",
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
        pw.SizedBox(height: 20),

        // Debtor Information Box
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "DEBTOR INFORMATION",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  _buildInfoRow("Name:", debtor.name),
                  pw.SizedBox(width: 40),
                  _buildInfoRow("Contact:", debtor.contact),
                  pw.SizedBox(width: 40),
                  _buildInfoRow("Credit Limit:", debtor.creditLimit),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for summary section
  pw.Widget _buildSummarySection(double totalPaid, double currentBalance) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "FINANCIAL SUMMARY",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard(
                "Total Debt",
                "GHS ${debtor.creditBalance.toStringAsFixed(2)}",
                PdfColors.red700,
              ),
              _buildSummaryCard(
                "Amount Paid",
                "GHS ${totalPaid.toStringAsFixed(2)}",
                PdfColors.green700,
              ),
              _buildSummaryCard(
                "Balance",
                  currentBalance<0
                      ? "(GHS ${currentBalance.abs().toStringAsFixed(2)})"
                      :"GHS ${currentBalance.toStringAsFixed(2)}",
                currentBalance > 0 ? PdfColors.orange700 : PdfColors.green700,
              ),
            ],
          ),
        ],
      ),
    );
  }

// Helper method for payment history section
  pw.Widget _buildPaymentHistorySection(List<Payment> payments, double initialDebt) {
    if (payments.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text(
          "No payment records found",
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    double runningTotal = 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "PAYMENT HISTORY",
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),

        // Table Header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Row(
            children: [
              _buildTableHeaderCell("Date", flex: 2),
              _buildTableHeaderCell("Amount (GHS)", flex: 2),
              _buildTableHeaderCell("Method", flex: 2),
              _buildTableHeaderCell("Balance (GHS)", flex: 2),
              _buildTableHeaderCell("Reference", flex: 3),
            ],
          ),
        ),

        // Table Rows
        pw.Column(
          children: payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            runningTotal += payment.amount;
            final runningBalance = initialDebt - runningTotal;

            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200),
                ),
              ),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                child: pw.Row(
                  children: [
                    _buildTableCell(DateFormat('yyyy-MM-dd').format(payment.createdat), flex: 2),
                    _buildTableCell(payment.amount.toStringAsFixed(2), flex: 2, isAmount: true),
                    _buildTableCell(_getPaymentMethodDisplay(payment.paymentMethod), flex: 2),
                    runningBalance < 0
                        ? _buildTableCell("(${runningBalance.abs().toStringAsFixed(2)})", flex: 2, isAmount: true)
                        :
                    _buildTableCell(runningBalance.toStringAsFixed(2), flex: 2, isAmount: true),
                    _buildTableCell(payment.reference.isNotEmpty ? payment.reference : "-", flex: 3),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        pw.SizedBox(height: 10),

        // Summary Row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                "Total Paid: GHS ${runningTotal.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// Helper method for footer
  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "This is a computer-generated document. No signature required.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              "Page 1 of 1",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

// Helper widget for info row
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 11)),
      ],
    );
  }

// Helper widget for summary card
  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

// Helper widget for table header cell
  pw.Widget _buildTableHeaderCell(String text, {required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

// Helper widget for table cell
  pw.Widget _buildTableCell(String text, {required int flex, bool isAmount = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        isAmount ? "GHS $text" : text,
        style: pw.TextStyle(fontSize: 10),
      ),
    );
  }

  String _getPaymentMethodDisplay(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'mobile_money':
        return 'Mobile Money';
      default:
        return method;
    }
  }

}

class AddDebtorDialog extends StatefulWidget {
  final Function(Debtor) onDebtorAdded;

  const AddDebtorDialog({super.key, required this.onDebtorAdded});

  @override
  State<AddDebtorDialog> createState() => _AddDebtorDialogState();
}

class _AddDebtorDialogState extends State<AddDebtorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _debtController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  void _submitDebtor() {
    if (_formKey.currentState!.validate()) {
      // Debtor newDebtor = Debtor(
      //   id: 'DBT${DateTime.now().millisecondsSinceEpoch}',
      //   name: _nameController.text.trim(),
      //   contact: _phoneController.text.trim(),
      //   branchId: _emailController.text.trim(),
      //   branchName: _addressController.text.trim(),
      //   creditBalance: double.parse(_debtController.text),
      //   payments: [],
      //   createdAt: DateTime.now(), companyId: '', companyName: '', customerType: '', paymentDuration: '', staff: '', creditLimit: '', amountpaid: null,
      // );

      // widget.onDebtorAdded(newDebtor);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E3A5F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add New Debtor',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter debtor\'s full name',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter phone number',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter email address',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: 'Enter physical address',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _debtController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Total Debt Amount *',
                  labelStyle: TextStyle(color: Colors.grey),
                  prefixText: 'GHS ',
                  hintText: '0.00',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter amount';
                  if (double.tryParse(value!) == null) return 'Invalid amount';
                  if (double.parse(value) <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submitDebtor,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Add Debtor'),
        ),
      ],
    );
  }
}