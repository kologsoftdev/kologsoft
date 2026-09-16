import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/debtorsbalmodel.dart';
import 'package:kologsoft/screens/debtors_balance.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class DebtorsBalView extends StatefulWidget {
  const DebtorsBalView({super.key});

  @override
  State<DebtorsBalView> createState() => _DebtorsBalViewState();
}

class _DebtorsBalViewState extends State<DebtorsBalView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController searchController = TextEditingController();
  String searchText = "";
  late final stockprovider= Provider.of<Datafeed>(context, listen: false);

  Stream<List<DebtorsBalModel>> getAllDebtors() {
    return db.collection('debtorsbalance').where('companyId',isEqualTo: stockprovider.companyid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtorsBalModel.fromJson(doc.data());
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text("Debtors Balance View"),
        backgroundColor: const Color(0xFF1B263B),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 700,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search debtor...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF182232),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DebtorsBalModel>>(
              stream: getAllDebtors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: \\${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No debtors found"));
                }
                final debtorsList = snapshot.data!;
                final filteredList = debtorsList.where((debtor) {
                  return debtor.name.toLowerCase().contains(searchText);
                }).toList();
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final d = filteredList[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
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
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_wallet, color: Colors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Amount: GHC ${d.amount}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    Text("Date: ${d.date != null ? DateFormat.yMMMd().format(d.date!) : ''}", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                  ],
                                ),
                              ),

                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DebtorsBalance(
                                            debtors: d,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.edit,
                                        color: Colors.orange),
                                  ),

                                  const SizedBox(width: 8),

                                  InkWell(
                                    onTap: () async {
                                      print(d.id);
                                      await db.collection('debtorsbalance').doc(d.id).delete();
                                      await db.collection('customers').doc(d.id.toLowerCase()).update({ 'creditBalance': FieldValue.increment(-double.parse(d.amount)),
                                      });
                                    },
                                    child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
