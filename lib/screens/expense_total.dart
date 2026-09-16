import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboardStats.dart';
import '../providers/Datafeed.dart';

class RespWidget extends StatelessWidget {
  final double cwidth;
  const RespWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 235,
      width: cwidth,
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
              const Text(
                "Expense",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.all(Radius.circular(4))
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.receipt_long, color: Colors.blue, size: 16,),
                  )
              )
            ],
          ),

          const SizedBox(height: 16),

          FittedBox(
              child:StreamBuilder<DashboardStats>(
                stream: Provider.of<Datafeed>(
                  context,
                  listen: false,
                ).dashboardStatsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text(
                      "0.00 GHC\nThis Month",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    );
                  }
                  final stats = snapshot.data!;
                  final datafeed=context.read<Datafeed>();

                  final expense = datafeed.accesslevel.toLowerCase() == 'super admin'
                      ? stats.companyExpenseValue
                      : stats.branchExpenseValue;
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: expense.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text: " GHC\n",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        const TextSpan(
                          text: "This Month",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )          ),

          const SizedBox(height: 6),

          Row(
            children: const [
              Icon(Icons.arrow_drop_up, color: Colors.redAccent, size: 22),
              SizedBox(width: 4),
              Text(
                "11%",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              SizedBox(width: 4),
              Text(
                "vs last month",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),

          const Spacer(),

          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "5",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: "%\n",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                TextSpan(
                  text: "Within this month",
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}