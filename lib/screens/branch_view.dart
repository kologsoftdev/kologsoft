import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../providers/Datafeed.dart';
import '../providers/cashier_provider.dart';
import 'branch_reg.dart';

class BranchView extends StatefulWidget {
  const BranchView({super.key});

  @override
  State<BranchView> createState() => _BranchViewState();
}

class _BranchViewState extends State<BranchView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? selectedDate;
  String searchQuery = '';


  @override
  void initState() {
    super.initState();
    Future.microtask((){
     context.read<Datafeed>().fetchBranches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BranchModel> filterbranches(List<BranchModel> branches) {
    if (searchQuery.isEmpty) return branches;

    final query = searchQuery.toLowerCase();
    return branches.where((s) {
      final Name = s.branchname.toLowerCase();
      final type = s.branchtype.toLowerCase();
      final staff = s.staff.toLowerCase();
      final updateby = s.updatedby.toLowerCase();
      final contact = s.branchcontact.toLowerCase();
     
      return Name.contains(query) ||type.contains(query)||staff.contains(query)||updateby.contains(query)|| contact.contains(query);
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(builder: (BuildContext context, Datafeed value, Widget? child) {

      final branhes =value.branches;
      final filterbranche = filterbranches(branhes);

      return Scaffold(
        backgroundColor: const Color(0xFF101624),
        appBar: AppBar(
          title: const Text("Registered Branches"),
          backgroundColor: const Color(0xFF1B263B),

        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF415A77),
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchRegistration()),
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
                        hintText: "Search branches by name, type, contact...",
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: filterbranche.length,
                        itemBuilder: (context,index){
                          final branch = filterbranche[index];

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
                                      // Text("${index +1}",style: TextStyle(color: Colors.white),),
                                      // SizedBox(height: 5,),
                                      Text( branch.branchname,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ), ),
                                      const SizedBox(height: 4),
                                      Text( "Type: ${branch.branchtype}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      Text(
                                        "Contact: ${branch.branchcontact}",
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                      Text(
                                        "Address: ${branch.address}",
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                                            builder: (_) => BranchRegistration(branch: branch,),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.edit, color: Colors.orange),
                                    ),
                                    SizedBox(width: 8),
                                    InkWell(
                                      onTap: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor: const Color(0xFF1B263B),
                                            title: const Text(
                                              "Delete Branch?",
                                              style: TextStyle(color: Colors.white),
                                            ),
                                            content: Text(
                                              "Are you sure you want to delete ${branch.branchname}?",
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

                                          final datafeed = Provider.of<CashierProvider>(context, listen: false);

                                          // remove locally first (instant UI update)
                                          value.branches.removeWhere((w) => w.id == branch.id);

                                          // delete in firestore
                                          await db.collection('branches').doc(branch.id).delete();

                                          // optional provider delete
                                          await datafeed.deleteBranch(branch.id);

                                          ScaffoldMessenger.of(context).showSnackBar(

                                            const SnackBar(
                                              backgroundColor: Colors.red,
                                                content: Text("Branch deleted successfully",style: TextStyle(color: Colors.white),)),
                                          );
                                        }
                                      },
                                      child: const Icon(Icons.delete_forever, color: Colors.red),
                                    ),
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
