import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/screens/account_type_reg.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class AccountTypeView extends StatefulWidget {
  const AccountTypeView({super.key});

  @override
  State<AccountTypeView> createState() => _AccountTypeViewState();
}

class _AccountTypeViewState extends State<AccountTypeView> {

  List <AccountTypeModel> accountList=[];

  final FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  Stream<List<AccountTypeModel>> getAllAccounts() {
    final provider=Provider.of<Datafeed>(context,listen: false);
    return db.collection('accounts').where('companyId', isEqualTo: provider.companyid).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AccountTypeModel.fromJson(doc.data());
      }).toList();
    });
  }


  @override
  void initState() {
    super.initState();
    getAllAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: Text("Account Types"),
        backgroundColor: const Color(0xFF1B263B),
      ),
      body: Column(
        children: [

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 700,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search account...",
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

          // LIST
          Expanded(
            child: StreamBuilder<List<AccountTypeModel>>(
              stream: getAllAccounts(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No accounts found"));
                }

                final accountList = snapshot.data!;

                // FILTERED LIST
                final filteredList = accountList.where((acc) {
                  return acc.name.toLowerCase().contains(searchText) ||
                      acc.accountClass.toLowerCase().contains(searchText) ||
                      acc.subAccount.toLowerCase().contains(searchText) ||
                      acc.accountClassType.toLowerCase().contains(searchText);
                }).toList();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                      itemBuilder: (context, index) {

                        final acc = filteredList[index];

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
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.store,
                                    color: Colors.blue),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Class: ${acc.accountClass}",
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      "Subclass: ${acc.subAccount}",
                                      style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "SubType: ${acc.accountClassType}",
                                      style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12),
                                    ),
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
                                          builder: (_) => AccountTypeReg(
                                            account: acc,
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
                                      await db
                                          .collection('accounts')
                                          .doc(acc.id)
                                          .delete();
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
