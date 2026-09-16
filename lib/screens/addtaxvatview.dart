
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/addtaxvatmodel.dart';
import '../providers/Datafeed.dart';
import 'addtaxvat.dart';


class AddTaxVatvatView extends StatefulWidget {
  const AddTaxVatvatView({super.key});

  @override
  State<AddTaxVatvatView> createState() => _AddTaxVatvatViewState();
}

class _AddTaxVatvatViewState extends State<AddTaxVatvatView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchaddVat();
    });
  }

filterVat(List<addTaxVatModel> list) {
    if (searchQuery.isEmpty) return list;

    final query = searchQuery.toLowerCase();

    return list.where((v) {
      return v.vattype.toLowerCase().contains(query) ;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final vatList = value.addvatList;
        final filtered = filterVat(vatList);

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            title: const Text("VAT Configuration"),
            backgroundColor: const Color(0xFF1B263B),
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const addTaxVat()),
              );

              /// REFRESH AFTER ADD
              // context.read<Datafeed>().fetchVat();
            },
          ),

          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [

                    /// SEARCH
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search VAT...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF182232),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// LIST
                    Expanded(
                      child: value.isloadingaddvatlist ?
                           Center(
                             child: CircularProgressIndicator(
                             color: Colors.white,
                           ),
                           )
                          :value.addvatList.isEmpty
                          ? const Center(
                        child: Text(
                          "No VAT Found",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                          : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                        final vat = filtered[index];
                        final vatType = vat.vattype;
                        final id = vat.id;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF182232),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [

                                /// ICON
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.receipt,
                                      color: Colors.green),
                                ),

                                const SizedBox(width: 12),

                                /// DETAILS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vat.vattype,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        "VAT Rate: ${vat.vatrate}",
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        "GetFund Rate: ${vat.vatgetfund}",
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        "NHIL: ${vat.nhil}",
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        "Covid-19: ${vat.covid19}",
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                /// ACTIONS
                                Row(
                                  children: [

                                    /// EDIT
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.push(context,
                                          MaterialPageRoute(
                                            builder: (_) => addTaxVat( vat: vat,docId: id,),
                                          ),
                                        );

                                        //context.read<Datafeed>().fetchVat();
                                      },
                                      child: const Icon(Icons.edit,
                                          color: Colors.orange),
                                    ),

                                    const SizedBox(width: 10),

                                    /// DELETE
                                    InkWell(
                                      onTap: () async {
                                        final confirm =  await showDialog<bool>(
                                          context: context,
                                          builder: (_) =>
                                              AlertDialog(
                                                backgroundColor: const Color(0xFF1B263B),
                                                title: const Text(
                                                    "Delete VAT?",
                                                    style: TextStyle(
                                                        color: Colors.white)),
                                                content: Text(
                                                  'Delete $vatType VAT?',
                                                  style: const TextStyle( color: Colors.white70),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>  Navigator.pop( context, false),
                                                    child: const Text("Cancel",style: TextStyle(color: Colors.white),),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context,true),
                                                    child: const Text( "Delete",
                                                        style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                        );

                                        if (confirm == true) {
                                          await db.collection('addvat').doc(id).delete();
                                          vatList.removeWhere((item) => item.id == vat.id);
                                         value.notifyListeners();

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.green,
                                              content: Text(
                                                  "VAT deleted successfully"),
                                            ),
                                          );
                                        }
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