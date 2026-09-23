import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import '../models/debtors.dart';
import '../models/paymentMethod.dart';
import '../models/salesmodel.dart';

class CashierProvider extends Datafeed {
  Set<String> deletingPayments = {};
  List<SalesModel> invoices = [];
  List<Debtor>debtorlist=[];
  List<Payment>debtordetails=[];
  List<Payment>debtpayments=[];
  String searchQuery = '';
  String statusFilter = 'All';
  final Map<String, String?> selectedNetworks = {};
  final Map<String, String?> selectedCardTypes = {};
  Map<String, String> selectedPaymentMethods = {};
  Map<String, double> changeAmounts = {};
  Map<String,List<String>> linkedAccounts={};
  // Local cache to track MOMO transaction statuses by transactionId
  Map<String, String> momoTransactionStatus = {};
  SalesModel? selectedInvoice;
  String? selectedInvoiceId;
  bool isLoadingpayment = false;
  final firestore = FirebaseFirestore.instance;
  double totalPendingAmount = 0;
  double totalPaidToday = 0;
  int pendingCount = 0;
  int paidCount = 0;
  final now = DateTime.now();
  late final defaultStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
  late final defaultEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  bool isLoadingDetails = false;

  Map<String, List<String>> regionsWithDistricts = {
    'Savannah Region': [
      'Bole District',
      'Central Gonja District',
      'East Gonja Municipal',
      'North Gonja District',
      'North East Gonja District',
      'Sawla-Tuna-Kalba District',
      'West Gonja Municipal',
    ],

    'North East Region': [
      'Bunkpurugu-Nakpanduri District',
      'Chereponi District',
      'East Mamprusi Municipal',
      'Mamprugu Moagduri District',
      'West Mamprusi Municipal',
      'Yunyoo-Nasuan District',
    ],

    'Northern Region': [
      'Gushegu Municipal',
      'Karaga District',
      'Kpandai District',
      'Kumbungu District',
      'Mion District',
      'Nanton District',
      'Nanumba North Municipal',
      'Nanumba South District',
      'Saboba District',
      'Sagnarigu Municipal',
      'Savelugu Municipal',
      'Tatale-Sanguli District',
      'Tamale Metropolitan',
      'Tolon District',
      'Yendi Municipal',
      'Zabzugu District',
    ],

    'Upper East Region': [
      'Bawku Municipal',
      'Bawku West District',
      'Binduri District',
      'Bolgatanga East District',
      'Bolgatanga Municipal',
      'Bongo District',
      'Garu District',
      'Kassena-Nankana Municipal',
      'Kassena-Nankana West District',
      'Nabdam District',
      'Pusiga District',
      'Talensi District',
      'Tempane District',
    ],
  };

  StreamSubscription<QuerySnapshot>? _invoiceSubscription;

   fetchPaymentMethods() async {
    try {

      final snapshot = await db
          .collection('paymentaccounts')
          .where('companyId', isEqualTo: companyid)
          .get();

      final Map<String, List<String>> tempMap = {};

      for (var doc in snapshot.docs) {
        final map = doc.data();

        final method = (map['paymentMethod'] as String?)?.toLowerCase() ?? '';

        final accounts = List<String>.from(map['linkedAccounts'] ?? []);

        if (method.isNotEmpty) {
          tempMap[method] = accounts;
        }
      }

      linkedAccounts = tempMap;
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
    } finally {
      notifyListeners();
    }
  }

 listenToInvoices(BuildContext context, {bool todayOnly = true,DateTime? startDate, DateTime? endDate,}) async {
    await getdata();
    isLoadingpayment = true;
    notifyListeners();

    try {
      Query query = firestore
          .collection('sales')
          .where('branchId', isEqualTo: branchid)
          .where('companyId', isEqualTo: companyid)
          .where('pricingtype', isEqualTo: 'Sales Point')
          .orderBy('createdAt', descending: true);

      final DateTime? start = todayOnly
          ? defaultStart
          : startDate;

      final DateTime? end = todayOnly
          ? defaultEnd
          : endDate;

      if (start != null && end != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
      }
      await _invoiceSubscription?.cancel();
      _invoiceSubscription = query.snapshots().listen(
            (snapshot) {
          invoices = snapshot.docs.map((doc)=>SalesModel.fromSnapshot(doc)).toList();
          _calculateStats();
          isLoadingpayment = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Stream error: $e');
          isLoadingpayment = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      isLoadingpayment = false;
      notifyListeners();
    }
  }

  void _calculateStats() {
    totalPendingAmount = 0;
    totalPaidToday = 0;
    pendingCount = 0;
    paidCount = 0;

    for (var invoice in invoices) {
      if ( invoice.amountPaid >= invoice.totalamount) {
        paidCount++;
        totalPaidToday += invoice.totalamount;
      } else {
        pendingCount++;
        totalPendingAmount += (invoice.totalamount - invoice.amountPaid);
      }
    }
  }
  void selectInvoice(String id,SalesModel invoicedata) {
    selectedInvoiceId = id;
      selectedInvoice = invoicedata;
    selectedPaymentMethods[id] = selectedPaymentMethods[id] ?? 'cash';
    notifyListeners();
  }
  void resetSelection() {
    selectedInvoice = null;
    selectedInvoiceId = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> processPayment(PaymentMethodModel paymentdata) async {
    isLoadingpayment = true;
    notifyListeners();

    try {
      final invoice = selectedInvoice;

      double totalPaid = paymentdata.amount;
      final paymentRecord = PaymentMethodModel(
        amount: paymentdata.amount,
        paymentmethod: paymentdata.paymentmethod,
        accountName: paymentdata.accountName,
        accountNumber: paymentdata.accountNumber,
        status: paymentdata.status,
        reference: paymentdata.reference,
      );

      final List<PaymentMethodModel> payments = (invoice?.payments as List? ?? []).map((e) => PaymentMethodModel.fromMap(e)).toList();
      payments.add(paymentRecord);

      if (paymentdata.paymentmethod!='cash' && paymentdata.balance>0) {
        payments.add(
          PaymentMethodModel(
            amount: paymentdata.balance,
            paymentmethod: "cash",
            accountName: "cash",
            accountNumber: "cash",
            reference: "part payment",
            status: true,
          ),
        );

        totalPaid = paymentdata.totalamount;
      }

      final paymentStatus = totalPaid >= paymentdata.totalamount ? 'paid' : 'partial';

      final paymentsMap = payments.map((e) => e.toMap()).toList();


      final updateData = {
        'amountPaid': totalPaid,
        'paymentStatus': paymentStatus,
        'payments': paymentsMap,
        'cashier': staff,
        'cashieremail': staffemail,
        if (paymentdata.paymentmethod == 'cash') 'change': paymentdata.change,
      };

      await firestore
          .collection('sales')
          .doc(paymentdata.id)
          .set(updateData, SetOptions(merge: true));

      invoice!
        ..amountPaid = totalPaid
        ..paymentStatus = paymentStatus;
      if (paymentdata.paymentmethod == 'cash') {
        invoice?.change = paymentdata.change;
      }

      changeAmounts[selectedInvoiceId!] = paymentdata.balance;

      return {
        'success': true,
        'change': paymentdata.change,
        'paymentStatus': paymentStatus,
        'totalPaid': paymentdata.amount,
        'remainingBalance':paymentdata.balance,
      };
    } catch (e) {
      debugPrint('Error processing payment: $e');
      rethrow;
    } finally {
      isLoadingpayment = false;
      notifyListeners();
    }
  }

  Future<void> printReceipt(String invoiceId,selectedInvoice) async {
     isLoadingpayment=true;
     notifyListeners();
    final salesRef = firestore.collection('sales').doc(invoiceId);
      try{
        await salesRef.set({
          'reciepted': true,
          'printed': true,
          'printedat': Timestamp.fromDate(DateTime.now()),
          'receiptat': Timestamp.fromDate(DateTime.now()),
          'receiptby': staff,
          'printedby': staff,
          'receiptbyemail': staffemail,
        }, SetOptions(merge: true));
        selectedInvoice.printed = true;
      }catch(e){
        print(e);
      }finally{
        isLoadingpayment=false;
        notifyListeners();
      }


  }

  @override
  void dispose() {
    _invoiceSubscription?.cancel();
    super.dispose();
  }

  void disposeControllers(String invoiceId) {
    selectedNetworks.remove(invoiceId);
  }

  loadDebtors() async {
   try {
      await getdata();
      Query query = db
          .collection('customers').where('companyid', isEqualTo: companyid)
          //.where('customertype', isEqualTo: "Credit")
          .where('creditBalance', isNotEqualTo: 0);
      final snapshot = await query.get();
     return debtorlist = snapshot.docs.map((doc) => Debtor.fromFirestore(doc)).toList();

    } catch (e) {
      print('Failed to load debtors: $e');
    }finally{
      notifyListeners();
    }
  }
  loadcustomers(String contact) async {
   try {
      await getdata();
      Query query = db
          .collection('customers').where('companyid', isEqualTo: companyid).where('contact', isEqualTo: contact).limit(1);
      final snapshot = await query.get();
     return debtorlist = snapshot.docs.map((doc) => Debtor.fromFirestore(doc)).toList();

    } catch (e) {
      print('Failed to load debtors: $e');
    }finally{
      notifyListeners();
    }
  }

 incrementMomoDebtPayment({
    required amount,required paymentmethod
  }) async {
    if (companyid.isEmpty || branchid.isEmpty || amount == 0) {
      return;
    }

    await db .collection("dashbaord_stats").doc(companyid).update({
      "companydebtpay_$paymentmethod":  FieldValue.increment(amount),

      "branchsales.$branchid.debtpay_$paymentmethod": FieldValue.increment(amount),
    });
  }



  Future<Debtor?> searchDebtorByContact(String contact) async {
    try {
      await getdata();

      final phone = contact.trim();

      if (phone.isEmpty) {
        return null;
      }

      final snapshot = await db
          .collection('customers')
          .where('companyid', isEqualTo: companyid)
          .where('contact', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final debtor = Debtor.fromFirestore(doc);

      // Do not return customers without outstanding credit.
      if (debtor.creditBalance <= 0) {
        return null;
      }

      return debtor;
    } catch (e) {
      print('Failed to search debtor: $e');
      return null;
    }
  }

  loadDebtorDetails({required String customerid}) async {
    try {
      isLoadingDetails = true;
      notifyListeners();
      await getdata();
      Query query = db
          .collection('debtpayment').where('companyid', isEqualTo: companyid).where('customerid', isEqualTo: customerid).orderBy("createdat",descending: true);
      final snapshot = await query.get();
      return debtordetails = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Payment.fromJson(data);
      }).toList();
    } catch (e) {
      print('Failed to load debtors details: $e');
    }finally{
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  DebtorPaymentTransactions({DateTime? startDate, DateTime? endDate}) async {
    try {
      isLoadingDetails = true;
      notifyListeners();
      await getdata();

      final effectiveStart = startDate ?? defaultStart;
      final effectiveEnd   = endDate ?? defaultEnd;

      Query query = db.collection('debtpayment').where('companyid', isEqualTo: companyid)
          // .where('createdat', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
          // .where('createdat', isLessThanOrEqualTo: Timestamp.fromDate(effectiveEnd))
          .orderBy('createdat', descending: true);
      final snapshot = await query.get();
      return debtpayments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Payment.fromJson(data);
      }).toList();
    } catch (e) {
      print('Failed to load debtors details: $e');
    }finally{
      isLoadingDetails = false;
      notifyListeners();
    }
  }

   debptpayment(
      Map<String, dynamic> paymentdata) async {
    try {
      final oldAmount = paymentdata['oldamount'] as double;
      final paymentmethod = paymentdata['paymentmethod'];
      await db.runTransaction((transaction) async {
        final customerRef = db.collection('customers').doc(paymentdata['customerid']);
        final paymentRef = db.collection('debtpayment').doc(paymentdata['id']);

        final newAmount = paymentdata['amount'] as double;
        final difference = newAmount - oldAmount;
        transaction.set(paymentRef, paymentdata, SetOptions(merge: true));

        if (difference != 0) {
          transaction.update(customerRef, {
            'amountpaid': FieldValue.increment(difference),
            'updatedat': FieldValue.serverTimestamp(),
          });
          final paymentIndex = debtpayments.indexWhere(
                (p) => p.id == paymentdata['id'],
          );

          if (paymentIndex != -1) {
            debtpayments[paymentIndex] = debtpayments[paymentIndex].copyWith(
              amount: newAmount,
              runningbalance: debtpayments[paymentIndex].runningbalance - difference,
            );
          }
          incrementMomoDebtPayment(amount: difference,paymentmethod:paymentmethod);

        }
      });

      final index = debtorlist.indexWhere((d) => d.id == paymentdata['customerid'],);
      if (index != -1) {
        final newAmount = paymentdata['amount'] as double;
        final difference = newAmount - oldAmount;
        debtorlist[index] = debtorlist[index].copyWith(amountpaid: debtorlist[index].amountpaid + difference,);
      }

      notifyListeners();
    } catch (e) {
      print('Payment error: $e');
    }
  }


  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    statusFilter = value;
    notifyListeners();
  }

  List<Debtor> get filteredDebtors {
    return debtorlist.where((debtor) {
      final matchesSearch = searchQuery.isEmpty ||
          debtor.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          debtor.contact.contains(searchQuery) ||
          debtor.id.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesStatus =
          statusFilter == 'All' || debtor.status == statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

   addPaymentToDebtor(String debtorId, Payment payment) {
    final index = debtorlist.indexWhere((d) => d.id == debtorId);

    if (index != -1) {
      final currentDebtor = debtorlist[index];

      final updatedPayments = List<Payment>.from(currentDebtor.payments ?? []);
      updatedPayments.add(payment);

      debtorlist[index] = currentDebtor.copyWith(
        payments: updatedPayments,
        amountpaid: currentDebtor.amountpaid + payment.amount,
      );

      notifyListeners();
    }
  }

  double get totalOutstandingBalance {
    return debtorlist.fold(0, (sum, debtor) => sum + debtor.balance);
  }

  double get totalCollected {
    return debtorlist.fold(0, (sum, debtor) => sum + debtor.amountpaid);
  }

  Future<void> deletePayment({required Payment payment, required String debtorId,}) async {

    try {
      deletingPayments.add(payment.id);
      notifyListeners();
      await db.runTransaction((transaction) async {
        final debtorRef = db.collection('customers').doc(debtorId);
        final paymentRef = db.collection('debtpayment').doc(payment.id);
        final debtorSnap = await transaction.get(debtorRef);

        if (!debtorSnap.exists) {
          throw Exception("Debtor does not exist");
        }

        final debtorData = debtorSnap.data() as Map<String, dynamic>;

        double currentPaid = (debtorData['amountpaid'] as num).toDouble();

        double newPaid = currentPaid - payment.amount;

        await transaction.update(debtorRef, {
          'amountpaid': newPaid,
        });
        await incrementMomoDebtPayment(amount: -payment.amount, paymentmethod: payment.paymentMethod);
        await transaction.delete(paymentRef);
      });

      debtpayments.removeWhere((p) => p.id == payment.id);

    } catch (e) {
      print("Transaction failed: $e");
      rethrow;
    }finally{
      deletingPayments.remove(payment.id);
      notifyListeners();
    }
  }

  /// Atomically mark MOMO transactions as 'saved' and append the paymentId.
  /// Returns a map of transactionId -> success(bool) indicating which updates succeeded.
  Future<Map<String, bool>> markMomoTransactionsSaved(List<String> transactionIds, String paymentId) async {
    final results = <String, bool>{};
    final batch = db.batch();

    try {
      for (final txId in transactionIds) {
        final query = await db
            .collection('momo')
            .where('transactionId', isEqualTo: txId)
            .where('companyid', isEqualTo: companyid)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          results[txId] = false;
          continue;
        }

        final doc = query.docs.first;
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'saved') {
          // Already used
          results[txId] = false;
          momoTransactionStatus[txId] = 'saved';
          continue;
        }

        final ref = doc.reference;
        batch.update(ref, {
          'status': 'saved',
          'paymentids': FieldValue.arrayUnion([paymentId])
        });
        results[txId] = true; // optimistic; will be applied on commit
        momoTransactionStatus[txId] = 'saved';
      }

      // Commit batch if there is at least one update
      final updates = results.values.where((v) => v).toList();
      if (updates.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking momo transactions: $e');
      // On error, reset optimistic marks for those txs we set
      for (final entry in results.entries) {
        if (entry.value) momoTransactionStatus.remove(entry.key);
        results[entry.key] = false;
      }
    }

    notifyListeners();
    return results;
  }
}
