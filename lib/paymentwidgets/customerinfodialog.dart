
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/customerreg_model.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/paymentwidgets/PDFprints/print_service.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/widgets/salespagewidgets/snackmsg.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/Receiptdatamodel.dart';
import '../models/branch.dart';
import '../models/paymentMethod.dart';
import '../models/salesmodel.dart';
import '../providers/SalesProvider.dart';
import 'customerselectiondialog.dart';
import 'invoice1.dart';
import 'receipt_formatter.dart';
import 'receipt_formaterA4.dart';
class CustomerInfoDialog {
  static Future<void> show({
    required BuildContext context,
    dynamic activeBranchId,
    ItemModel? selectedItem,

  }) async {
    final salesItems = context.read<SalesProvider>().salesItems;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController referenceController = TextEditingController();
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final TextEditingController amountPaidController = TextEditingController();

    await datafeed.getdata();
    String company =datafeed.company;
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    final resolvedBranchId = (activeBranchId?.toString().isNotEmpty == true)
        ? activeBranchId.toString()
        : datafeed.branchid;

    final resolvedBranch = datafeed.branches.firstWhere(
          (b) => b.id == resolvedBranchId,
      orElse: () => BranchModel(),
    );

    final resolvedBranchName = resolvedBranch.branchname.isNotEmpty
        ? resolvedBranch.branchname
        : datafeed.branch;

    final resolvedBranchType = resolvedBranch.branchtype?.isNotEmpty == true
        ? resolvedBranch.branchtype!
        : datafeed.branchtype;
    bool canPrint = datafeed.canPrint ;

    final allowed = datafeed.allowedPaymentMethods;
    String paymentMethod = allowed.isNotEmpty ? allowed.first : '';
    final totalDiscount = salesProvider.calculateDiscountTotal();
    double totalAmount = salesProvider.calculateTaxableTotal();
    Map<String, dynamic>? selectedCreditCustomer;
    String customerType = '';

    final bool isCreditNow = paymentMethod == 'credit';
    final String transactionType = isCreditNow ? 'credit' : 'cash';

    String? selectedMomoNetwork = 'MTN';
    String selectedMomoProvider = 'Merchant';
    String paymentStatus = 'pending';
    final isSalesBranch = datafeed.branchtype == "Sales Branch";
    double paidAmount = 0.0;
    double newBalance = 0.0;
    String printedBy = '';
    String receiptBy = '';
    String accountName = '';
    String accountNumber = '';
    String reference = '';
    double changeAmount =0.0;
    bool printed = false;
    bool reciepted = false;
    bool status = false;
    bool isSaving = false;
    bool isSavingA4 = false;
    Timestamp? printedAt;
    Timestamp? receiptAt;

    List<PaymentMethodModel> payments = [];
    List<TextEditingController> momoTransactionControllers = [TextEditingController()];
    List<TextEditingController> momoTransactionAmountControllers = [TextEditingController()];
    List<bool> momoTransactionAmountLoaded = [false];
    List<Timer?> momoTransactionTimers = [null];

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

    bool isValidPhone(String phone) {
      return RegExp(r'^(?:0\d{9}|\+233\d{9})$').hasMatch(phone);
    }
    void showError(String message) {
      salesProvider.showMessageDialog(context, message, Colors.red);
    }

    bool handleBank() {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      if (!canPrint) {
        if (name.isEmpty ) {
          showError('Enter name ');
          return false;
        }
        if (name.length < 2) {
          showError('$name must be more than one letter ');
          return false;
        }
        if ( phone.isEmpty) {
          showError('Enter  phone');
          return false;
        }
        if (!isValidPhone(phone)) {
          showError('Enter valid phone number');
          return false;
        }
      }

      if (canPrint) {
        final amountText = amountPaidController.text.trim();
        if (referenceController.text.trim().isEmpty) {
          showError('Enter reference');
          return false;
        }
        if (amountText.isEmpty) {
          showError('Enter bank amount');
          return false;
        }

        final amount = double.tryParse(amountText);

        if (amount == null) {
          showError('Invalid bank amount');
          return false;
        }

        if (amount <= 0) {
          showError('Amount must be greater than 0');
          return false;
        }
      }

      return true;
    }

    bool handleCard() {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      if (!canPrint) {
        if (name.isEmpty ) {
          showError('Enter name ');
          return false;
        }
        if (name.length < 2) {
          showError('$name must be more than one letter ');
          return false;
        }
        if ( phone.isEmpty) {
          showError('Enter  phone');
          return false;
        }
        if (!isValidPhone(phone)) {
          showError('Enter valid phone number');
          return false;
        }
      }
      if (canPrint) {
        final amountText = amountPaidController.text.trim();
        if (referenceController.text.trim().isEmpty) {
          showError('Enter card reference');
          return false;
        }
        if (amountText.isEmpty) {
          showError('Enter card amount');
          return false;
        }

        final amount = double.tryParse(amountText);

        if (amount == null) {
          showError('Invalid card amount');
          return false;
        }

        if (amount <= 0) {
          showError('Amount must be greater than 0');
          return false;
        }
      }
      return true;
    }

    bool handleMomo() {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      if (!canPrint) {
        if (name.isEmpty ) {
          showError('Enter name ');
          return false;
        }
        if (name.length < 2) {
          showError('$name must be more than one letter ');
          return false;
        }
        if ( phone.isEmpty) {
          showError('Enter  phone');
          return false;
        }
        if (!isValidPhone(phone)) {
          showError('Enter valid phone number');
          return false;
        }
      }
      if (canPrint) {
        final amountText = amountPaidController.text.trim();
        if ( phone.isEmpty) {
          showError('Enter  phone');
          return false;
        }
        if (!isValidPhone(phone)) {
          showError('Enter valid phone number');
          return false;
        }
        if (selectedMomoNetwork == null) {
          showError('Select MOMO network');
          return false;
        }
        if (amountText.isEmpty) {
          showError('Enter MOMO amount');
          return false;
        }

        final amount = double.tryParse(amountText);

        if (amount == null) {
          showError('Invalid MOMO amount');
          return false;
        }

        if (amount <= 0) {
          showError('Amount must be greater than 0');
          return false;
        }
        if (isSalesBranch) {
          if (amount > totalAmount) {
            showError('Amount must not exceed ${totalAmount.toStringAsFixed(2)}');
            return false;
          }
        }

        final transactionEntries = <Map<String, dynamic>>[];
        for (int i = 0; i < momoTransactionControllers.length; i++) {
          final transactionId = momoTransactionControllers[i].text.trim();
          final amountText = momoTransactionAmountControllers[i].text.trim();
          final transactionAmount = double.tryParse(amountText);

          if (transactionId.isEmpty && amountText.isEmpty) continue;
          if (transactionId.isEmpty) {
            showError('Enter transaction ID ${i + 1}');
            return false;
          }
          if (amountText.isEmpty) {
            showError('Enter amount for transaction ${i + 1}');
            return false;
          }
          if (!momoTransactionAmountLoaded[i]) {
            showError('Submit transaction ID ${i + 1} to load amount from momo collection');
            return false;
          }
          if (transactionAmount == null) {
            showError('Invalid amount for transaction ${i + 1}');
            return false;
          }
          if (transactionAmount <= 0) {
            showError('Amount must be greater than 0 for transaction ${i + 1}');
            return false;
          }
          transactionEntries.add({
            'transactionId': transactionId,
            'amount': transactionAmount,
          });
        }

        if (transactionEntries.isEmpty) {
          showError('Enter at least one MOMO transaction ID and amount');
          return false;
        }
      }
      return true;
    }

    bool handleCash() {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

        if (name.isEmpty ) {
          showError('Enter name ');
          return false;
        }
        if (name.length < 2) {
          showError('$name must be more than one letter ');
          return false;
        }
        if ( phone.isEmpty) {
          showError('Enter  phone');
          return false;
        }
        if (!isValidPhone(phone)) {
          showError('Enter valid phone number');
          return false;
        }


        return true;


    }
    bool handleCredit() {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      if (name.isEmpty) {
        showError('Enter name');
        return false;
      }
      if (name.length < 2) {
        showError('$name must be more than one letter');
        return false;
      }
      if (phone.isEmpty) {
        showError('Enter phone');
        return false;
      }
      if (!isValidPhone(phone)) {
        showError('Enter valid phone number');
        return false;
      }
      if (selectedCreditCustomer != null) {
        final creditLimit = double.tryParse(
          (selectedCreditCustomer?['creditlimit'] ?? '').toString(),
        );
        double balance = double.tryParse('${selectedCreditCustomer?['creditBalance']}') ?? 0;
        double total = double.tryParse('$totalAmount') ?? 0;

         newBalance = balance + total;
        if (creditLimit != null) {
          final total = salesProvider.calculateTaxableTotal();

          if (total > creditLimit) {
            showError('Credit limit exceeded\nLimit: $creditLimit');
            return false;
          }
        }
       if(creditLimit!=null&& newBalance > creditLimit){
         showError('Credit limit exceeded\nLimit: $creditLimit');
         return false;
       }
        status = true;
        return true;
      }

      status = true;
      return true;
    }
    bool validateInputs() {
      switch (paymentMethod) {
        case 'cash':
          return handleCash();

        case 'momo':
          return handleMomo();

        case 'card':
          return handleCard();

        case 'bank_transfer':
        case 'cheque':
          return handleBank();

        case 'credit':
          return handleCredit();

        default:
          showError('Select a payment method');
          return false;
      }
    }
    /// Prevent opening dialog with empty cart
    if (salesItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add items to the sale first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final db =FirebaseFirestore.instance;
    String customerId='';
    String customerName ='';
    String customerPhone='';
    dynamic customerCreditLimit;

    String? _selectedPrinter;
    List<String> _availablePrinters = [];
    String? _savedPrinter;

    // Load printer info
    Future<void> _loadPrinterInfo() async {
      final saved = await PrintService.getSavedPrinter();
      final all = await PrintService.getPrinters();
      _savedPrinter = saved;
      _availablePrinters = all;
      _selectedPrinter ??= saved ?? (all.isNotEmpty ? all.first : null);
    }

    _loadPrinterInfo();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final horizontalPad = (screenWidth * 0.10).clamp(12.0, 60.0);

          void _showPrinterSelectionDialog(BuildContext ctx, StateSetter stateSetter) {
            showDialog(
              context: ctx,
              builder: (dlgContext) => AlertDialog(
                backgroundColor: const Color(0xFF1A1F3A),
                title: Text(
                  'Select Printer',
                  style: TextStyle(color: Colors.white),
                ),
                content: _availablePrinters.isEmpty
                    ? Text(
                  'No printers found',
                  style: TextStyle(color: Colors.white70),
                )
                    : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _availablePrinters.map((printer) {
                      final isCurrent = _selectedPrinter == printer;
                      final isSaved = printer == _savedPrinter;
                      return ListTile(
                        title: Text(
                          printer,
                          style: TextStyle(
                            color: isCurrent ? Colors.teal : Colors.white,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check, color: Colors.teal)
                            : (isSaved
                            ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SAVED',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                            : null),
                        onTap: () {
                          stateSetter(() {
                            _selectedPrinter = printer;
                          });
                          Navigator.pop(dlgContext);
                        },
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dlgContext),
                    child: Text(
                      'Close',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            );
          }

          void updateMomoPaidTotal() {
            final total = momoTransactionAmountControllers
                .map((controller) => double.tryParse(controller.text.trim()) ?? 0)
                .fold(0.0, (sum, value) => sum + value);
            setState(() {
              amountPaidController.text = total.toStringAsFixed(2);
            });
          }

          Future<void> fetchMomoAmountForTransaction(int index) async {
            final transactionId = momoTransactionControllers[index].text.trim();
            if (transactionId.isEmpty) {
              return;
            }
            final query = await datafeed.db
                .collection('momo')
                .where('transactionId', isEqualTo: transactionId)
                .limit(1)
                .get();

            if (query.docs.isEmpty) {
              showError('MOMO transaction $transactionId not found');
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
              showError('Transaction ID $transactionId has already been used');
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
              showError('Unable to parse amount for transaction $transactionId');
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
          }

          Future<void> submitSale({required bool printA4}) async {
            //String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final formattedDate = context.read<SalesProvider>().saleDate;
            final isValid = validateInputs();
            if (!isValid) return;
            final bool isCreditNow = paymentMethod == 'credit';
            final String transactionType = isCreditNow ? 'credit' : 'cash';
            setState(() => isSaving = true);
            final momoTransactionIds = paymentMethod == 'momo'
                ? getMomoTransactionMap()
                : <String, dynamic>{};

            try {
              switch (paymentMethod) {
                case 'cash':
                  if (!handleCash()) {
                    setState(() => isSaving = false);
                    return;
                  }
                  accountName = 'cash';
                  accountNumber = 'cash';
                  break;
                case 'momo':
                  if (!handleMomo()) {
                    setState(() => isSaving = false);
                    return;
                  }
                  if (canPrint || isSalesBranch) {
                    accountName = selectedMomoNetwork ?? 'MTN';
                    accountNumber = phoneController.text.trim();
                    reference = phoneController.text.trim();
                    status = false;
                    paymentStatus = 'paid';
                  }
                  break;
                case 'card':
                  if (!handleCard()) {
                    setState(() => isSaving = false);
                    return;
                  }
                  if (canPrint || isSalesBranch) {
                    accountName = 'card';
                    accountNumber = 'card';
                    reference = referenceController.text.trim();
                    status = true;
                    paymentStatus = 'paid';
                  }
                  break;
                case 'bank_transfer':
                case 'cheque':
                  if (!handleBank()) {
                    setState(() => isSaving = false);
                    return;
                  }
                  if (canPrint || isSalesBranch) {
                    accountName = 'bank';
                    accountNumber = 'bank_transfer';
                    reference = referenceController.text.trim();
                    status = true;
                    paymentStatus = 'paid';
                  }
                  break;
                case 'credit':
                  if (!handleCredit()) {
                    setState(() => isSaving = false);
                    return;
                  }
                  payments.clear();
                  paidAmount = 0;
                  paymentStatus = 'pending';
                  break;
              }

             /* if (!salesProvider.ensureSalesWarehouseSelected(context, datafeed, selectedItem, requireItemSelection: false)) {
                setState(() => isSaving = false);
                return;
              }

              if (!await salesProvider.validateCartStockOnSave(context, salesItems, datafeed)) {
                setState(() => isSaving = false);
                return;
              } */
              final isService =
                  (selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

              if (!isService) {
                if (!salesProvider.ensureSalesWarehouseSelected(context, datafeed, selectedItem, requireItemSelection: false)) {
                  setState(() => isSaving = false);
                  return;
                }

                if (!await salesProvider.validateCartStockOnSave(context, salesItems, datafeed)) {
                  setState(() => isSaving = false);
                  return;
                }
              }
              if (isCreditNow) {

                customerId = (selectedCreditCustomer?['id'] ?? '').toString();
                customerName = (selectedCreditCustomer?['name'] ?? '').toString();
                customerPhone = (selectedCreditCustomer?['contact'] ?? selectedCreditCustomer?['phone'] ?? '').toString();
                customerType = 'credit';
                // await db.collection('customers').doc(customerId).update({
                //   'creditBalance': FieldValue.increment(salesProvider.calculateTaxableTotal()),
                // });
                final formatter = NumberFormat.currency(
                  locale: 'en_GH',
                  symbol: 'GHS',
                  decimalDigits: 2,
                );

                String smsCreditbalance = formatter.format(salesProvider.calculateTaxableTotal());


                final smsRecord = {
                  'companyid': datafeed.companyid,
                  'branchid': datafeed.branchid,
                  'staff': datafeed.staff,
                  'message': "Dear $customerName, goods valued at $smsCreditbalance have been supplied on credit to your account. Kindly settle the outstanding balance promptly. Thank you.",                                    'senderid': "",
                  'recipient': customerPhone,
                  'type': 'single',
                  'bulkFilterType': null,
                  'status': 'pending',
                  'successMessage': '',
                  'failureReason': '',
                  'createdAt': Timestamp.now(),
                  'updatedAt': Timestamp.now(),
                };
                print("SMS Record: ${datafeed.companyid},$smsCreditbalance");
                await db.collection('sms_logs').add(smsRecord);
              }
              else {
                customerName = nameController.text.trim();
                customerPhone = phoneController.text.trim();
                customerType = 'cash';
                newBalance = 0.0;
                customerId = '${datafeed.companyid.toLowerCase()}_${phoneController.text.trim()}';
                final existingDoc = datafeed.db.collection('customers');
                final ref = existingDoc.doc(customerId).get();

                if (!(await ref).exists) {
                  final provider = Provider.of<Datafeed>(context, listen: false);
                  await provider.getdata();
                  final customer = CustomerRegModel(
                    id: customerId,
                    branchname: provider.selectedBranch?.branchname ?? '',
                    branchid: provider.selectedBranch?.id ?? '',
                    name: customerName,
                    contact: customerPhone,
                    customertype: customerType,
                    creditlimit: customerCreditLimit,
                    companyid: datafeed.companyid,
                    staff: datafeed.staff,
                    date: DateTime.now(),
                    updatedby: null,
                    updatedat: null,
                    deletedat: null,
                    companyname: company,
                    creditBalance: newBalance.toString(),
                  );
                  await datafeed.db.collection('customers').doc(customerId).set(customer.toMap());
                }
              }

              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final saleDocId = '${datafeed.companyid}_${datafeed.staffPosition}_$timestamp';
              final receiptNumber = '${datafeed.staffPosition}$timestamp';
              final itemsMap = {
                for (int i = 0; i < salesItems.length; i++) 'item_$i': salesItems[i]
              };
              final enteredAmount = double.tryParse(amountPaidController.text.trim()) ?? 0;

              payments.clear();
              changeAmount = 0;
              paidAmount = totalAmount;
              if ((canPrint || isSalesBranch) && !isCreditNow) {
                if (paymentMethod == 'cash') {
                  payments.add(
                    PaymentMethodModel(
                      amount: totalAmount,
                      accountName: 'cash',
                      accountNumber: 'cash',
                      status: true,
                      reference: 'cash',
                      paymentmethod: 'cash',
                    ),
                  );
                  receiptAt = Timestamp.now();
                  printedAt = Timestamp.now();
                  status = true;
                  printed = true;
                  reciepted = true;
                  printedBy = datafeed.staff;
                  receiptBy = datafeed.staff;
                  paymentStatus = 'paid';
                } else {
                  if (enteredAmount < totalAmount) {
                    final remaining = double.parse((totalAmount - enteredAmount).toStringAsFixed(2));
                    if (enteredAmount > 0) {
                      payments.add(
                        PaymentMethodModel(
                          amount: enteredAmount,
                          accountName: accountName,
                          accountNumber: accountNumber,
                          status: status,
                          reference: reference,
                          paymentmethod: paymentMethod,
                        ),
                      );
                    }
                    payments.add(
                      PaymentMethodModel(
                        amount: remaining,
                        accountName: 'cash',
                        accountNumber: 'cash',
                        status: true,
                        paymentmethod: 'cash',
                      ),
                    );
                    paymentStatus = 'paid';
                    receiptAt = Timestamp.now();
                    printedAt = Timestamp.now();
                    status = true;
                    printed = true;
                    reciepted = true;
                    printedBy = datafeed.staff;
                    receiptBy = datafeed.staff;
                  } else {
                    final change = double.parse((enteredAmount - totalAmount).toStringAsFixed(2));
                    payments.add(
                      PaymentMethodModel(
                        amount: enteredAmount,
                        accountName: accountName,
                        accountNumber: accountNumber,
                        status: status,
                        reference: reference,
                        paymentmethod: paymentMethod,
                        transactionIds: paymentMethod == 'momo' ? momoTransactionIds : null,
                      ),
                    );
                    changeAmount = change;
                    receiptAt = Timestamp.now();
                    printedAt = Timestamp.now();
                    status = true;
                    printed = true;
                    reciepted = true;
                    printedBy = datafeed.staff;
                    receiptBy = datafeed.staff;
                  }
                }
              } else {
                payments = [];
                paidAmount = 0;
                printedBy = '';
                receiptBy = '';
                printed = false;
                reciepted = false;
                status = false;
                payments.clear();
                paymentStatus = 'pending';
                if (isCreditNow) {
                  receiptAt = Timestamp.now();
                  printedAt = Timestamp.now();
                  status = true;
                  printed = true;
                  reciepted = true;
                  printedBy = datafeed.staff;
                  receiptBy = datafeed.staff;

                }
              }

              final paymentsMap = payments.map((e) => e.toMap()).toList();
              final now = DateTime.now();
              final day = DateFormat('EEEE').format(now);
              final year = now.year.toString();
              final month = '${now.year}.${now.month}';
              final weekNumber = ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
              final week = '${now.year}.$weekNumber';

              final saleData = SalesModel(
                id: saleDocId,
                companyId: datafeed.companyid,
                companyname: datafeed.company,
                branchId: resolvedBranchId,
                branchName: resolvedBranchName,
                branchType: resolvedBranchType,
                pricingtype: resolvedBranchType,
                staffPosition: datafeed.staffPosition,
                payments: paymentsMap,
                receiptNumber: receiptNumber,
                receiptby: receiptBy,
                receiptat: receiptAt,
                paymentStatus: paymentStatus,
                transMode: transactionType,
                items: itemsMap,
                totalamount: salesProvider.calculateGrossTotal(),
                amountPaid: paidAmount,
                discount: salesProvider.calculateDiscountTotal(),
                change: 0.0,
                itemCount: salesItems.length,
                isreturned: false,
                createdAt: Timestamp.fromDate(DateTime.now()),
                createdBy: datafeed.staff,
                approvedby: datafeed.staff,
                printedby: printedBy,
                printedat: printedAt,
                staffemail: datafeed.staffemail,
                receiptbyemail: datafeed.staffemail,
                dateymd: formattedDate,
                stockCheckedAt: Timestamp.fromDate(DateTime.now()),
                timestamp: timestamp,
                printed: printed,
                customerId: customerId,
                customerName: customerName,
                customerPhone: customerPhone,
                reciepted: reciepted,
                day: day,
                week: week,
                month: month,
                year: year,
                supplystatus: false,

              );

              await datafeed.db.collection('sales').doc(saleDocId).set(saleData.toMap());

             // final approved = await salesProvider.ensureSaleApproved(context, saleDocId);
              final skipCheck = salesProvider.isServiceOnlySale(salesProvider.salesItems);
              final approved = await salesProvider.ensureSaleApproved(context, saleDocId, skipStockCheck: skipCheck);

              if (!approved) {
                setState(() => isSaving = false);
                return;
              }

              if (paymentMethod == 'momo') {
                final momoTransactions = getMomoTransactionMap();
                for (final transactionId in momoTransactions.keys) {
                  final query = await datafeed.db
                      .collection('momo')
                      //.where('companyid', isEqualTo: datafeed.companyid)
                      .where('transactionId', isEqualTo: transactionId)
                      .limit(1)
                      .get();
                  if (query.docs.isNotEmpty) {
                    await query.docs.first.reference.update({
                      'status': 'saved',
                      'salesid': saleDocId,
                      'companyid': datafeed.companyid,
                      'branchid': datafeed.branchid,
                      'staff': datafeed.staff,
                      'updatedAt': Timestamp.now(),
                    });
                  }
                }
              }

              if (canPrint || isSalesBranch || isCreditNow) {
                final receiptData = ReceiptData(
                  cashier: datafeed.staff,
                  barcode: receiptNumber,
                  transactionId: saleDocId,
                  items: salesItems.map((e) {
                    return ReceiptItem(
                      name: e['item'] ?? '',
                      qty: double.tryParse(e['quantity'].toString()) ?? 0,
                      price: double.tryParse(e['price'].toString()) ?? 0,
                      mode: e['mode'],
                      isService: (e['producttype']?.toString().toLowerCase().trim() ?? '') == 'service',
                    );
                  }).toList(),
                  companyName: datafeed.company,
                  contact: datafeed.branchphone,
                  customername: customerName,
                  datetime: DateTime.now(),
                  receiptNumber: receiptNumber,
                  paymentMethod: paymentMethod,
                  payable: totalAmount,
                  amountPaid: totalAmount,
                  discount: totalDiscount,
                  subTotal: totalAmount,
                  change: changeAmount,
                  receiptName: isCreditNow ? 'INVOICE' : 'OFFICIAL RECEIPT',
                  email: datafeed.companyemail,
                  vatPercent: 15,
                  vatInclusiveAmount: salesProvider.amountPayable(),
                  vatAmount: salesProvider.calculateVatFromInclusive(totalAmount),
                  branch: datafeed.branch,
                  address: datafeed.branchaddress,
                  Customertin: '',
                  Suppliertin: '',
                );

                final isWindowsDesktop = !kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.windows;

                if (printA4) {
                  final generator = ReceiptPrinterA4();
                  if (isWindowsDesktop) {
                    if (_selectedPrinter != null) {
                      await generator.printA4Pdf(
                        printerName: _selectedPrinter!,
                        data: receiptData,
                      );
                    }
                  } else {
                    final doc = await generator.buildPdfA4(receiptData);
                    await Printing.layoutPdf(
                      name: saleDocId,
                      onLayout: (format) async => doc.save(),
                    );
                  }
                } else {
                  final generator = ReceiptPrinter();
                  final doc = await generator.buildPdf(receiptData);
                  if (isWindowsDesktop) {
                    if (_selectedPrinter != null) {
                      final width = receiptWidthForPrinter(_selectedPrinter!);
                      final rawReceipt = buildRawReceiptText(receiptData, width: width);
                      final rawResult = await PrintService.printRaw(
                        printerName: _selectedPrinter!,
                        text: rawReceipt,
                      );
                      if (!rawResult.success) {
                        await PrintService.printPdf(
                          printerName: _selectedPrinter!,
                          pdf: doc,
                        );
                      }
                    }
                  } else {
                    await Printing.layoutPdf(
                      name: saleDocId,
                      onLayout: (format) async => doc.save(),
                    );
                  }
                }
              }

              if (context.mounted) {
                snackMsg(context, 'Sale saved! Receipt: $receiptNumber', Colors.green);
                context.read<SalesProvider>().clearCurrentCart();
                Navigator.pop(context);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            } finally {
              if (context.mounted) {
                setState(() => isSaving = false);
              }
            }
          }

          Widget buildAmountField({bool isReadOnly = false}) {
            return   TextFormField(
              controller: amountPaidController,
              autofocus: true,
              readOnly: isReadOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 20),
              onChanged: (value) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Amount Paid by Customer',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixText: 'GHS ',
                prefixStyle: const TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                fillColor: const Color(0xFF22304A),
                filled: true,
              ),
            );
          }
          Widget buildReferenceField() {
            return    TextFormField(
              controller: referenceController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: ' Reference*',
                labelStyle: const TextStyle(
                  color: Colors.white70,
                ),
                prefixIcon: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF9C27B0),
                ),
                filled: true,
                fillColor: const Color(0xFF22304A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          // Widget buildMomoFields() {
          //   if (!canPrint) return const SizedBox();
          //
          //   return Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       const SizedBox(height: 12),
          //       Container(
          //         padding: const EdgeInsets.symmetric(
          //           horizontal: 16,
          //         ),
          //         decoration: BoxDecoration(
          //           color: const Color(0xFF22304A),
          //           borderRadius: BorderRadius.circular(12),
          //         ),
          //         child: DropdownButtonHideUnderline(
          //           child: DropdownButton<String>(
          //             value: selectedMomoNetwork,
          //             isExpanded: true,
          //             hint: const Text(
          //               'Select MOMO Network',
          //               style: TextStyle(color: Colors.white70),
          //             ),
          //             dropdownColor: const Color(0xFF22304A),
          //             style: const TextStyle(color: Colors.white),
          //             items: ['MTN', 'Vodafone', 'AirtelTigo'].map(
          //                   (network) => DropdownMenuItem<String>(
          //                 value: network,
          //                 child: Row(
          //                   children: [
          //                     Icon(
          //                       Icons.sim_card,
          //                       color: network == 'MTN'
          //                           ? Colors.yellow
          //                           : network == 'Vodafone'
          //                           ? Colors.red
          //                           : Colors.blue,
          //                     ),
          //                     const SizedBox(width: 8),
          //                     Text(network),
          //                   ],
          //                 ),
          //               ),
          //             ).toList(),
          //             onChanged: (value) {
          //               if(value != null){
          //                 setState(() {
          //                   selectedMomoNetwork = value;
          //                 });
          //               }
          //             },
          //           ),
          //         ),
          //       ),
          //       const SizedBox(height: 12),
          //       TextFormField(
          //         controller: phoneController,
          //         keyboardType: TextInputType.phone,
          //         style: const TextStyle(color: Colors.white),
          //         // enabled: paymentMethod != 'credit',
          //         decoration: InputDecoration(
          //           labelText: 'Phone Number *',
          //           labelStyle: const TextStyle(
          //             color: Colors.white70,
          //           ),
          //           prefixIcon: const Icon(
          //             Icons.phone,
          //             color: Color(0xFF4CAF50),
          //           ),
          //           filled: true,
          //           fillColor: const Color(0xFF22304A),
          //           border: OutlineInputBorder(
          //             borderRadius: BorderRadius.circular(12),
          //           ),
          //         ),
          //       ),
          //       const SizedBox(height: 12),
          //       buildAmountField(isReadOnly: true),
          //       const SizedBox(height: 12),
          //       Column(
          //         children: [
          //           for (int index = 0; index < momoTransactionControllers.length; index++)
          //             Padding(
          //               padding: const EdgeInsets.only(bottom: 12),
          //               child: Row(
          //                 children: [
          //                   Expanded(
          //                     child: TextFormField(
          //                       controller: momoTransactionControllers[index],
          //                       style: const TextStyle(color: Colors.white),
          //                       decoration: InputDecoration(
          //                         labelText: 'Transaction ID ${index + 1}',
          //                         labelStyle: const TextStyle(color: Colors.white70),
          //                         prefixIcon: const Icon(
          //                           Icons.confirmation_number,
          //                           color: Colors.orange,
          //                         ),
          //                         filled: true,
          //                         fillColor: const Color(0xFF22304A),
          //                         border: OutlineInputBorder(
          //                           borderRadius: BorderRadius.circular(12),
          //                         ),
          //                       ),
          //                       textInputAction: TextInputAction.next,
          //                       onChanged: (value) {
          //                         momoTransactionTimers[index]?.cancel();
          //                         momoTransactionTimers[index] = Timer(
          //                           const Duration(milliseconds: 500),
          //                           () => fetchMomoAmountForTransaction(index),
          //                         );
          //                       },
          //                       onFieldSubmitted: (_) {
          //                         fetchMomoAmountForTransaction(index);
          //                       },
          //                     ),
          //                   ),
          //                   const SizedBox(width: 8),
          //                   Expanded(
          //                     child: TextFormField(
          //                       controller: momoTransactionAmountControllers[index],
          //                       readOnly: true,
          //                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
          //                       inputFormatters: [
          //                         FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          //                       ],
          //                       style: const TextStyle(color: Colors.white),
          //                       onChanged: (_) {
          //                         updateMomoPaidTotal();
          //                       },
          //                       decoration: InputDecoration(
          //                         labelText: 'Amount ${index + 1}',
          //                         labelStyle: const TextStyle(color: Colors.white70),
          //                         prefixText: 'GHS ',
          //                         prefixStyle: const TextStyle(
          //                           color: Colors.green,
          //                           fontSize: 16,
          //                           fontWeight: FontWeight.bold,
          //                         ),
          //                         filled: true,
          //                         fillColor: const Color(0xFF22304A),
          //                         border: OutlineInputBorder(
          //                           borderRadius: BorderRadius.circular(12),
          //                         ),
          //                       ),
          //                     ),
          //                   ),
          //                   if (index > 0) ...[
          //                     const SizedBox(width: 8),
          //                     InkWell(
          //                       onTap: () {
          //                         setState(() {
          //                           momoTransactionControllers[index].dispose();
          //                           momoTransactionAmountControllers[index].dispose();
          //                           momoTransactionTimers[index]?.cancel();
          //                           momoTransactionControllers.removeAt(index);
          //                           momoTransactionAmountControllers.removeAt(index);
          //                           momoTransactionAmountLoaded.removeAt(index);
          //                           momoTransactionTimers.removeAt(index);
          //                           updateMomoPaidTotal();
          //                         });
          //                       },
          //                       child: const Icon(Icons.close, color: Colors.red),
          //                     ),
          //                   ],
          //                 ],
          //               ),
          //             ),
          //           SizedBox(
          //             width: double.infinity,
          //             child: OutlinedButton.icon(
          //               onPressed: () {
          //                 setState(() {
          //                   momoTransactionControllers.add(TextEditingController());
          //                   momoTransactionAmountControllers.add(TextEditingController());
          //                   momoTransactionAmountLoaded.add(false);
          //                   momoTransactionTimers.add(null);
          //                 });
          //               },
          //               icon: const Icon(Icons.add, color: Colors.white),
          //               label: const Text(
          //                 'Add transaction id',
          //                 style: TextStyle(color: Colors.white),
          //               ),
          //               style: OutlinedButton.styleFrom(
          //                 side: const BorderSide(color: Colors.white24),
          //                 backgroundColor: const Color(0xFF22304A),
          //                 shape: RoundedRectangleBorder(
          //                   borderRadius: BorderRadius.circular(12),
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ],
          //   );
          // }
          Widget buildMomoFields() {

            if (!canPrint) return const SizedBox();

            Widget buildProviderSelector() {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF22304A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMomoProvider,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF22304A),
                    style: const TextStyle(color: Colors.white),
                    items: ['Merchant', 'Hubtel'].map(
                          (provider) => DropdownMenuItem<String>(
                        value: provider,
                        child: Text(provider),
                      ),
                    ).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMomoProvider = value;
                        });
                      }
                    },
                  ),
                ),
              );
            }

            if (selectedMomoProvider == 'Hubtel') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  buildProviderSelector(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF4CAF50)),
                      filled: true,
                      fillColor: const Color(0xFF22304A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22304A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMomoNetwork,
                        isExpanded: true,
                        hint: const Text(
                          'Select MOMO Network',
                          style: TextStyle(color: Colors.white70),
                        ),
                        dropdownColor: const Color(0xFF22304A),
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
                          if(value != null){
                            setState(() {
                              selectedMomoNetwork = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                buildProviderSelector(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22304A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMomoNetwork,
                      isExpanded: true,
                      hint: const Text(
                        'Select MOMO Network',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: const Color(0xFF22304A),
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
                        if(value != null){
                          setState(() {
                            selectedMomoNetwork = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone,
                      color: Color(0xFF4CAF50),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF22304A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                buildAmountField(isReadOnly: true),
                const SizedBox(height: 12),
                Column(
                  children: [
                    for (int index = 0; index < momoTransactionControllers.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: momoTransactionControllers[index],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Transaction ID ${index + 1}',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(
                                    Icons.confirmation_number,
                                    color: Colors.orange,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF22304A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (value) {
                                  momoTransactionTimers[index]?.cancel();
                                  momoTransactionTimers[index] = Timer(
                                    const Duration(milliseconds: 500),
                                        () => fetchMomoAmountForTransaction(index),
                                  );
                                },
                                onFieldSubmitted: (_) {
                                  fetchMomoAmountForTransaction(index);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: momoTransactionAmountControllers[index],
                                readOnly: true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) {
                                  updateMomoPaidTotal();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Amount ${index + 1}',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixText: 'GHS ',
                                  prefixStyle: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF22304A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            if (index > 0) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    momoTransactionControllers[index].dispose();
                                    momoTransactionAmountControllers[index].dispose();
                                    momoTransactionTimers[index]?.cancel();
                                    momoTransactionControllers.removeAt(index);
                                    momoTransactionAmountControllers.removeAt(index);
                                    momoTransactionAmountLoaded.removeAt(index);
                                    momoTransactionTimers.removeAt(index);
                                    updateMomoPaidTotal();
                                  });
                                },
                                child: const Icon(Icons.close, color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            momoTransactionControllers.add(TextEditingController());
                            momoTransactionAmountControllers.add(TextEditingController());
                            momoTransactionAmountLoaded.add(false);
                            momoTransactionTimers.add(null);
                          });
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Add transaction id',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: const Color(0xFF22304A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          Widget buildCardFields() {
            if (!canPrint) return const SizedBox();

            return Column(
              children: [
                const SizedBox(height: 12),

                buildReferenceField(),

                const SizedBox(height: 10),
                buildAmountField(),
              ],
            );
          }
          Widget buildBankFields() {
            if (!canPrint) return const SizedBox();

            return Column(
              children: [
                const SizedBox(height: 12),

                buildReferenceField(),

                const SizedBox(height: 10),
                buildAmountField(),
              ],
            );
          }
          Widget buildCreditFields() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF415A77),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await CustomerSelectionDialog.showCustomerDialog(
                        context: context,
                       // salesItems: salesItems,
                      );

                      if (picked != null) {
                        setState(() {

                        });
                      }

                      if (picked == null) return;
                      setState(() {
                        selectedCreditCustomer = picked;
                        nameController.text = (picked['name'] ?? '').toString();
                        phoneController.text = (picked['contact'] ??  picked['phone'] ??  '').toString();
                      });
                    },
                    icon: const Icon(Icons.search),
                    label: Text(
                      selectedCreditCustomer == null
                          ? 'Select Customer (Credit)'
                          : 'Change Customer',
                    ),
                  ),
                ),
                if (selectedCreditCustomer != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22304A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (selectedCreditCustomer?['name'] ?? '')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${(selectedCreditCustomer?['contact'] ?? selectedCreditCustomer?['phone'] ?? '').toString()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Credit Limit: ${(selectedCreditCustomer?['creditlimit'] ?? 'N/A').toString()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            );
          }
          Widget buildCashFields() {
            return Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF415A77),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await CustomerSelectionDialog.showCustomerDialog(
                        context: context,
                        // salesItems: salesItems,
                      );

                      if (picked != null) {
                        setState(() {

                        });
                      }

                      if (picked == null) return;
                      setState(() {
                        selectedCreditCustomer = picked;
                        nameController.text = (picked['name'] ?? '').toString();
                        phoneController.text = (picked['contact'] ??  picked['phone'] ??  '').toString();
                      });
                    },
                    icon: const Icon(Icons.search),
                    label: Text(
                      selectedCreditCustomer == null
                          ? 'Select Customer (Credit)'
                          : 'Change Customer',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if(canPrint || isSalesBranch)...[
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  // enabled: paymentMethod != 'credit',
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: Color(0xFFFF9800),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF22304A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  // enabled: paymentMethod != 'credit',
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone,
                      color: Color(0xFF4CAF50),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF22304A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                  const SizedBox(height: 2),
                ],
                const SizedBox(height: 5),
              ],
            );
          }
          Widget buildCustomerInfo(){
            return Column(
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  enabled: paymentMethod != 'credit',
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: Color(0xFFFF9800),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF22304A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  enabled: paymentMethod != 'credit',
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone,
                      color: Color(0xFF4CAF50),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF22304A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          }
          Widget buildPaymentFields() {
            switch (paymentMethod) {
              case 'momo':
                return buildMomoFields();

              case 'card':
                return buildCardFields();

              case 'bank_transfer':
              case 'cheque':
                return buildBankFields();

              case 'credit':
                return buildCreditFields();

              case 'cash':
                return buildCashFields();

              default:
                return const SizedBox();
            }
          }
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: 12,
            ),

            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                width: screenWidth * 0.80,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6F00), Color(0xFFFF9800)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.person_add, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Customer Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
              
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
              
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22304A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Builder(
                               builder: (context) {
                                  // Normalize allowed payment methods to a set.
                                  final allowedSet = allowed.map((e) => e.toString().trim().toLowerCase(),)
                                      .where((e) => e.isNotEmpty).toSet();
                                  final bool gate = allowedSet.isNotEmpty;
              
                                  bool isAllowed(String method) {
                                    if (!gate) return false;
                                    return allowedSet.contains(method);
                                  }
              
                                  Widget methodTile({
                                    required String label,
                                    required String value,
                                    required Color active,
                                  })
                                  {
                                    if (!isAllowed(value)) {
                                      return const SizedBox.shrink();
                                    }
                                    return RadioListTile<String>(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: EdgeInsets.zero,
                                      materialTapTargetSize:   MaterialTapTargetSize.shrinkWrap,
                                      title: Text( label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      value: value,
                                      groupValue: paymentMethod,
                                      onChanged: (val) async{
                                        setState(()  {
                                          paymentMethod = val!;
                                          amountPaidController.clear();
                                          referenceController.clear();
                                          nameController.clear();
                                          phoneController.clear();
                                          if (paymentMethod != 'credit') {
                                            selectedCreditCustomer = null;
                                          }
                                          if (paymentMethod != 'momo') {
                                            selectedMomoNetwork = 'MTN';

                                          }
                                        });

                                      },
                                      activeColor: active,
                                      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                                        if (states.contains(
                                          MaterialState.selected,
                                        ))
                                        {
                                          return active;
                                        }
                                        return Colors.white54;
                                      }),
                                    );
                                  }
              
                                  final methodWidgets = <Widget>[
                                    methodTile(
                                      label: 'Credit',
                                      value: 'credit',
                                      active: const Color(0xFFFF9800),
                                    ),
                                    methodTile(
                                      label: 'Cash',
                                      value: 'cash',
                                      active: const Color(0xFF4CAF50),
                                    ),
                                    methodTile(
                                      label: 'Bank Transfer',
                                      value: 'bank_transfer',
                                      active: const Color(0xFF2196F3),
                                    ),
                                    methodTile(
                                      label: 'Card',
                                      value: 'card',
                                      active: const Color(0xFF9C27B0),
                                    ),
                                    methodTile(
                                      label: 'Cheque',
                                      value: 'cheque',
                                      active: const Color(0xFF607D8B),
                                    ),
                                    methodTile(
                                      label: 'MOMO',
                                      value: 'momo',
                                      active: const Color(0xFFE91E63),
                                    ),
                                  ].where((w) => w is! SizedBox).toList();
              
                                  if (methodWidgets.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'No payment methods enabled for this user.\nEnable them in Staff setup.',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    );
                                  }
              
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      final columns = width < 360 ? 1 : 2;
                                      final spacing = 12.0;
                                      final tileWidth = columns == 1  ? width
                                          : (width - spacing) / 2;
              
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: 6,
                                        children: methodWidgets
                                            .map((w) => SizedBox(
                                            width: tileWidth,
                                            child: w,
                                          ),
                                        ).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 20),

                            buildPaymentFields(),

                            const SizedBox(height: 22),

                            // if(!canPrint || (paymentMethod =='credit'))...[
                            //   buildCustomerInfo(),
                            // ],
                            if((!canPrint && paymentMethod != 'cash') || (paymentMethod == 'credit'))...[
                              buildCustomerInfo(),
                            ],
                            const SizedBox(height: 10),
                            const Divider(color: Colors.white24),

                            // Printer Status Card
                            if (canPrint || isSalesBranch)
                           Container(
                                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22304A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Printer',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.print,
                                                  color: Colors.teal,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _selectedPrinter ?? 'No printer',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (_selectedPrinter == _savedPrinter && _savedPrinter != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'SAVED',
                                                        style: TextStyle(
                                                          color: Colors.greenAccent,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.withOpacity(0.3),
                                            foregroundColor: Colors.teal,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () => _showPrinterSelectionDialog(context, setState),
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text(
                                            'Change',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                        Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [

                         TextButton(
                            onPressed: isSaving ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSaving ? null : () async => submitSale(printA4: false),
                            child: isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text('Save Customer', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isSaving ? null : () async => submitSale(printA4: true),
                            child: isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text('A4 Print', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
            ),
            ),
            ),
          );

        },

      ),
    );

  }
}
