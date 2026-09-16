import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dashboardStats.dart';
import '../models/sales_summary.dart';
import '../providers/Datafeed.dart';

class WorkPlaceWidget extends StatefulWidget {
  final double cwidth;
  const WorkPlaceWidget({super.key, required this.cwidth});

  @override
  State<WorkPlaceWidget> createState() => _WorkPlaceWidgetState();
}


class _WorkPlaceWidgetState extends State<WorkPlaceWidget> {

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
     double stotal=0.00;
    datafeed.dashboardStatsStream().listen((DashboardStats stats) {

      stotal = datafeed.accesslevel.toLowerCase() == 'super admin'? stats.companySalesValue : stats.branchSalesValue;
    });
    return Container(
      width: widget.cwidth,
      height: 235,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182232),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Sales",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.shopping_cart, color: Colors.greenAccent, size: 16,),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<SalesSummary>(
            stream: datafeed.StodayTotalsStream(),
            builder: (context, snapshot) {
              final cashTotal = snapshot.hasData ? snapshot.data!.cash!.toStringAsFixed(2) : '0.00';
              final creditTotal = snapshot.hasData ? snapshot.data!.credit!.toStringAsFixed(2) : '0.00';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      "GHS ${NumberFormat('#,##0.00').format(stotal)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    "Sales Today",
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:  [
                            Text(
                              //"GHS ${NumberFormat('#,##0.00').format(cashTotal)}",
                              "GHS ${cashTotal}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Cash Sales",
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.bookmark_added_outlined, color: Colors.white, size: 12,),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:  Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:  [
                            Text(
                              "Credit Sales",
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Text(
                             // "GHS ${NumberFormat('#,##0.00').format(creditTotal)}",
                              "GHS $creditTotal",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          height: 20,
                          width: 20,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}