import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import '../models/branch_stock_value.dart';
import '../models/dashboardStats.dart';
import '../models/sales_summary.dart';


class DashboardProvider extends Datafeed {
List<BranchStockItem>? branchStockValue=[];
double totalStockVal=0.00;
SalesSummary? _salesSummary;
SalesSummary? get salesSummary => _salesSummary;

DashboardProvider() {
  //_listenToSalesSummary();
}

void _listenToSalesSummary() {
  StodayTotalsStream().listen((summary) {
    _salesSummary = summary;
    notifyListeners();
  });
}


  // otherwise uses `branchSummary` entries for branch-level totals.
  Stream<WeeklySalesComparison> weeklySalesComparisonStream({String? selectedBranch}) {
    String _toDateOnly(DateTime d) =>
        "${d.year.toString().padLeft(4, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')}";

    double _n(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String _str(dynamic v) => v?.toString() ?? '';

    DateTime _startOfWeek(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

    final now = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final previousWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    final startStr = _toDateOnly(previousWeekStart);
    final endStr = _toDateOnly(currentWeekStart.add(const Duration(days: 6)));

    return db
        .collection('salesSummary')
        .where('companyid', isEqualTo: companyid)
        .where('summarydate', isGreaterThanOrEqualTo: startStr)
        .where('summarydate', isLessThanOrEqualTo: endStr)
        .snapshots()
        .map((snapshot) {
      final totalsByDate = <String, double>{};

      final branchKey = (selectedBranch == null || (selectedBranch.trim().isEmpty))
          ? ((accesslevel.toLowerCase() != 'super admin' && branchid.isNotEmpty) ? branchid : null)
          : selectedBranch;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dayKey = _str(data['summarydate']);
        if (dayKey.isEmpty) continue;

        double dayTotal = 0.0;

        // If user is super admin and no branch filter specified, use company-level cash+credit
        if ((accesslevel.toLowerCase() == 'super admin') && branchKey == null) {
          dayTotal = _n(data['cash'] ?? data['companycash'] ?? 0) + _n(data['credit'] ?? data['companycredit'] ?? 0);
        } else {
          // Otherwise use branchSummary entries (respect selectedBranch or user's branch)
          final branchSummary = data['branchSummary'] as Map<String, dynamic>? ?? {};
          for (final branchEntry in branchSummary.entries) {
            final branchData = branchEntry.value as Map<String, dynamic>? ?? {};
            final branchIdValue = _str(branchData['branchId'] ?? branchEntry.key);

            if (branchKey != null && branchIdValue != branchKey && branchEntry.key != branchKey) {
              continue;
            }

            // Preserve existing business logic: prefer branchsales_value or sales_value
            dayTotal += _n(branchData['cash'] ?? branchData['credit'] ?? 0);
          }
        }

        totalsByDate[dayKey] = (totalsByDate[dayKey] ?? 0) + dayTotal;
      }

      final currentWeek = List.generate(7, (index) {
        final day = currentWeekStart.add(Duration(days: index));
        return totalsByDate[_toDateOnly(day)] ?? 0.0;
      });

      final previousWeek = List.generate(7, (index) {
        final day = previousWeekStart.add(Duration(days: index));
        return totalsByDate[_toDateOnly(day)] ?? 0.0;
      });

      return WeeklySalesComparison(
        currentWeek: currentWeek,
        previousWeek: previousWeek,
        currentWeekStart: currentWeekStart,
      );
    });
  }

Stream<DashboardDocument> dashboardStream() {
  return db
      .collection('dashbaord_stats')
      .doc(companyid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      return DashboardDocument(
        stats: DashboardStats(
          companySalesValue: 0,
          companyExpenseValue: 0,
          branchSalesValue: 0,
          branchExpenseValue: 0, companyCash: 0, companyCard: 0, companyCredit: 0, companyMomo: 0, companyBankTransfer: 0, branchCash: 0, branchCard: 0, branchCredit: 0, branchMomo: 0, branchBankTransfer: 0, companyStockValue: 0, branchStockValue: 0, companyopening_credit_bal: 0, branchopening_credit_bal: 0, smsBalance: 0, companyDiscount: 0, branchDiscount: 0, companydebtpay_momo: 0, branchdebtpay_momo: 0, companystockreorderbal: 0, companyfinishedstock: 0, companyavailablestock: 0,
        ),
        stock: BranchStock(
          companyId: '',
          stockInTotal: 0,
          updatedAt: DateTime.now(),
          branches: {},
        ),
        raw: {},
      );
    }

    return DashboardDocument.fromFirestore(
      doc.data()!,
      branchid,
    );
  });
}

StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  void listenToBranchStock() async {
    try {
      await getdata();
      if (companyid == null || companyid.toString().trim().isEmpty) {
        debugPrint('Company ID is null or empty');
        return;
      }

      _subscription = FirebaseFirestore.instance
          .collection('dashbaord_stats')
          .doc(companyid)
          .snapshots()
          .listen(
            (doc) {
          try {
            if (!doc.exists || doc.data() == null) {
              branchStockValue = [];
              return;
            }

            final branchStock = BranchStock.fromMap(doc.data()!);
            branchStockValue = branchStock.branches.values.toList();
            totalStockVal = branchStock.stockInTotal;
            notifyListeners();
          } catch (innerError, stackTrace) {
            // Handle parsing or mapping errors
            debugPrint('Error processing branch stock snapshot: $innerError');
            debugPrintStack(stackTrace: stackTrace);
            branchStockValue = [];
          }
        },
        onError: (error, stackTrace) {
          // Handle Firestore stream errors
          debugPrint('Firestore stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
          branchStockValue = [];
        },
      );
    } catch (error, stackTrace) {
      // Handle setup errors (e.g., invalid companyid, Firestore issues)
      debugPrint('Error setting up branch stock listener: $error');
      debugPrintStack(stackTrace: stackTrace);
      branchStockValue = [];
    }
  }

  @override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}

}
